---
id: 793
layout: post
title: 'PostgresSQL BRIN 索引的使用的那些坑'
date: 2019-02-04 00:00:01
author: MonoUno
tags: 后端
---


作者：@monouno，现实习于长亭科技。原文发表在 (https://zhuanlan.zhihu.com/p/50167673)[https://zhuanlan.zhihu.com/p/50167673]

BRIN 索引（块范围索引，Block Range Indexes）是 PostgreSQL 9.5 版本新增的索引类型。该索引维护每一定范围内数据块的最大最小值和其他一些统计数据，当数据库查询时可根据索引的统计信息筛选出不符合查询条件的数据块，以避免全表扫描，提高性能和减少 IO。和 BTree 索引比较所占用的空间足够小<sup>[1]</sup>，因此 BRIN 索引一般用于线性相关较强字段的精确和范围查询，如在一张很大的日志表中通过 id 或时间查询。

## 创建测试数据

创建数据表，只含有一个 id 字段

```sql
CREATE TABLE example AS SELECT generate_series(1, 100000000) AS id;
```

数据表大小为 `3.4G`

```
\dt+ example
                      List of relations
 Schema |  Name   | Type  |  Owner   |  Size   | Description
--------+---------+-------+----------+---------+-------------
 public | example | table | safeline | 3457 MB |
(1 row)
```

创建索引

```sql
CREATE INDEX idx ON example USING brin(id) WITH (pages_per_range=1024, autosummarize=on);
```

索引大小为 `56K`

```
\dti+ idx
                        List of relations
 Schema | Name | Type  |  Owner   |  Table  | Size  | Description
--------+------+-------+----------+---------+-------+-------------
 public | idx  | index | safeline | example | 56 kB |
(1 row)
```

explain 一下 BRIN 索引使用情况

```sql
EXPLAIN ANALYZE SELECT * FROM example WHERE id = 492167;
```

```
                                                           QUERY PLAN
--------------------------------------------------------------------------------------------------------------------------------
 Gather  (cost=1016.26..807981.92 rows=1 width=4) (actual time=12.700..86.880 rows=1 loops=1)
   Workers Planned: 2
   Workers Launched: 2
   ->  Parallel Bitmap Heap Scan on example  (cost=16.26..806981.82 rows=1 width=4) (actual time=56.477..80.759 rows=0 loops=3)
         Recheck Cond: (id = 492167)
         Rows Removed by Index Recheck: 77141
         Heap Blocks: lossy=496
         ->  Bitmap Index Scan on idx  (cost=0.00..16.26 rows=230946 width=0) (actual time=0.377..0.377 rows=10240 loops=1)
               Index Cond: (id = 492167)
 Planning Time: 0.318 ms
 Execution Time: 86.950 ms
(11 rows)
```

索引很小，尝试使用 B-Tree 索引，体积会是 `2.1G`，大约是数据本身的三分之二大小了。

```
create index idx_btree on example (id);
```

```
\dti+ idx_btree
                            List of relations
 Schema |   Name    | Type  |  Owner   |  Table  |  Size   | Description
--------+-----------+-------+----------+---------+---------+-------------
 public | idx_btree | index | safeline | example | 2142 MB |
(1 row)
```

## BRIN 索引结构

BRIN 索引页的存储顺序依次是 `meta page`、`revmap pages` 和 `regular pages`。我们通过 [pageinspect](https://www.postgresql.org/docs/current/pageinspect.html#id-1.11.7.31.6) 扩展可以很方便地分析 BRIN 索引的各个页。

### meta page

第一页 `meta page` 保存 BRIN 索引的元数据

```
select * from brin_metapage_info(get_raw_page('idx', 0));

   magic    | version | pagesperrange | lastrevmappage
------------+---------+---------------+----------------
 0xA8109CFA |       1 |          1024 |              1
(1 row)
```

其中 `lastrevmapage` 表示 `revmap pages` 最后一页的下标，即从 `meta page` 的下一页到 `lastrevmapage` 都是 `revmap pages`。

### revmap pages

接下来的 revmap 相当于一个目录，保存数据块到索引记录的映射关系，而且每一页 revmap 的记录数是固定的。

```
SELECT * FROM brin_revmap_data(get_raw_page('idx', 1)) LIMIT 5;

 pages
-------
 (2,1)
 (2,2)
 (2,3)
 (2,4)
 (2,5)
(5 rows)
```

[下面的宏](https://github.com/postgres/postgres/blob/master/src/backend/access/brin/brin_revmap.c)可以计算出一个数据块在 revmap 中的位置，然后可以在 revmap 中查询到索引的位置。

```clike
#define HEAPBLK_TO_REVMAP_BLK(pagesPerRange, heapBlk) \
	((heapBlk / pagesPerRange) / REVMAP_PAGE_MAXITEMS)
#define HEAPBLK_TO_REVMAP_INDEX(pagesPerRange, heapBlk) \
	((heapBlk / pagesPerRange) % REVMAP_PAGE_MAXITEMS)
```

所以在扫描和更新索引时（比如 [brininsert](https://github.com/postgres/postgres/blob/322548a8abe225f2cfd6a48e07b99e2711d28ef7/src/backend/access/brin/brin.c#L188) 等函数），可以简单的计算出一个数据块属于哪一条索引记录<sup>[2]</sup>。

如果对应块索引还未被创建，那么该项就是 `(0, 0)`。随着表数据行和索引记录的不断增加，索引的 `revmap pages` 也会向后扩展，为了给这腾出位置，PostgreSQL 会从前面开始将 `regular pages` 中的索引条目移到末尾，并更新和拓展 `revmap`。

### regular page

可以通过 `brin_page_items` 查看索引记录

```
SELECT * FROM brin_page_items(get_raw_page('idx', 2), 'idx') LIMIT 5;

 itemoffset | blknum | attnum | allnulls | hasnulls | placeholder |        value
------------+--------+--------+----------+----------+-------------+---------------------
          1 |      0 |      1 | f        | f        | f           | {1 .. 231424}
          2 |   1024 |      1 | f        | f        | f           | {231425 .. 462848}
          3 |   2048 |      1 | f        | f        | f           | {462849 .. 694272}
          4 |   3072 |      1 | f        | f        | f           | {694273 .. 925696}
          5 |   4096 |      1 | f        | f        | f           | {925697 .. 1157120}
(5 rows)
```

其中 `blknum`、`attnum`、`allnulls`、`hasnulls`、`value` 分别表示起始块数、字段下标、是否全为空值、是否存在空值和块范围内字段的最大最小值。这其中最重要的就是 value 这个字段了。PostgreSQL 就是根据这个 value 值来判断是否需要扫描这些数据块。以第三个条目为例，它的 `blknum` 为 2048，说明是 2048 - 3072 数据块存储的数据范围是 `462849 .. 694272`。如果我们查询的 SQL 是 `WHERE id = 492167`，那在这些数据块中再搜索就足够了。

BRIN 索引的 `pages_per_range` 可指定单条索引记录所统计的数据块范围，默认为 128。值越小统计的粒度就越小，索引的过滤性越好，但索引也会越大。由于每筛选一次字段 PostgreSQL 都要扫描全部的 BRIN 索引，所花费的时间也会变长，因此需要根据表的大小与应用场景去调整其值的大小。

当一些在索引条目边界的行被删除时，会使原有的索引条目失效，失效的索引条目需要重新统计。也可以通过 `brin_desummarize_range` 手动将一些索引条目失效。

## 我们遇到的问题

我们有一张日志表需要不断插入大量请求日志，在用户浏览日志列表或是查看日志详情时需要进行等值或范围查询，起初在对 BRIN 索引进行测试时，先对日志表插入大量数据再建立索引进行查询，或是将之前归档的日志数据恢复再进行查询均有着不错的性能表现，但再进一步使用真实场景测试一段时间后发现日志查询变得非常慢，和之前的结果相差甚远。

### 只要数据插入足够快，索引就跟不上我

PostgreSQL 在插入或更新行时会更新已存在的索引条目，对应的索引条目不存在时则跳过。而在 `vacuum` 或显式调用 `brin_summarize_new_values` 时才会为表中未统计的数据块新增索引条目。从 PostgreSQL 10 开始新增 `autosummarize` 参数，开启 `autosummarize` 后，当表不断被插入新的行导致新增的数据块大于 `pages_per_range` 时，将会自动统计这些新增的数据块并为此插入新的索引条目。

`autosummarize` 并不会立即开始且都会成功，它尝试在 `AutoAacuumWork` 的请求队列中追加一项 `AVW_BRINSummarizeRange` 的任务，而这个任务便是调用 `summarize_range` 函数<sup>[3]</sup>。

```clike
if (!lastPageTuple)
{
    bool		recorded;

    recorded = AutoVacuumRequestWork(AVW_BRINSummarizeRange,
                                        RelationGetRelid(idxRel),
                                        lastPageRange);
    if (!recorded)
        ereport(LOG,
                (errcode(ERRCODE_PROGRAM_LIMIT_EXCEEDED),
                    errmsg("request for BRIN range summarization for index \"%s\" page %u was not recorded",
                        RelationGetRelationName(idxRel),
                        lastPageRange)));
}
else
    LockBuffer(buf, BUFFER_LOCK_UNLOCK);
```

请求队列的长度 `NUM_WORKITEMS` 是固定的，默认为 256。在 `autovacuum_work` 执行 `do_autovacuum` 时处理这些任务<sup>[4]</sup>。

```clike
/*
 * Perform additional work items, as requested by backends.
 */
LWLockAcquire(AutovacuumLock, LW_EXCLUSIVE);
for (i = 0; i < NUM_WORKITEMS; i++)
{
    AutoVacuumWorkItem *workitem = &AutoVacuumShmem->av_workItems[i];

    if (!workitem->avw_used)
        continue;
    if (workitem->avw_active)
        continue;
    if (workitem->avw_database != MyDatabaseId)
        continue;

    /* claim this one, and release lock while performing it */
    workitem->avw_active = true;
    LWLockRelease(AutovacuumLock);

    perform_work_item(workitem);

    /*
     * Check for config changes before acquiring lock for further jobs.
     */
    CHECK_FOR_INTERRUPTS();
    if (got_SIGHUP)
    {
        got_SIGHUP = false;
        ProcessConfigFile(PGC_SIGHUP);
    }

    LWLockAcquire(AutovacuumLock, LW_EXCLUSIVE);

    /* and mark it done */
    workitem->avw_active = false;
    workitem->avw_used = false;
}
LWLockRelease(AutovacuumLock);
```

当前 `AutoVacuumWorkItemType` 只有 `AVW_BRINSummarizeRange` 这一种，在 PostgreSQL 未来的版本很可能会继续使用这一框架，新增更多来自 backend 的任务类型。

当请求队列已满且 `autovacuum_work` 来不及处理时 `autosummarize` 就会失败。只要数据插入足够快，索引就跟不上我，所以即便是开启了 `autosummarize`，在大量数据被不断插入表中的情况下，请求队列会被迅速占满，导致 `autosummarize` 失败，出现大量错误日志：

```
XXXX-XX-XX 09:39:55.832 UTC [67] LOG:  request for BRIN range summarization for index "idx" page 58311 was not recorded
```

BRIN 索引需要定期被更新，否则就可能存在大量还未索引的记录，还有数据更新也导致一些索引条目失效或统计出现偏差。在 BRIN 索引不完整时过滤性能变差，无论查询的记录是否在已存在的索引条目中，在 Heap bitmap index scan 之后仍需要重新 Recheck 未统计的数据块，速度可能会变得非常缓慢，从原来的十几毫秒延长到几秒是有可能的，进而影响相关的业务系统。下面是一个比较极端的情况下的查询。

```
EXPLAIN (analyze,buffers) SELECT * FROM example WHERE id > 100 AND id <= 2000;

                                                       QUERY PLAN
-------------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on example  (cost=12.03..50726.88 rows=1 width=37) (actual time=19.317..6047.938 rows=1900 loops=1)
   Recheck Cond: ((id > 100) AND (id <= 2000))
   Rows Removed by Index Recheck: 39598741
   Heap Blocks: lossy=330006
   Buffers: shared hit=1 read=330007
   ->  Bitmap Index Scan on idx  (cost=0.00..12.03 rows=15355 width=0) (actual time=19.085..19.085 rows=3301120 loops=1)
         Index Cond: ((id > 100) AND (id <= 2000))
         Buffers: shared hit=1 read=1
 Planning Time: 0.782 ms
 Execution Time: 6048.140 ms
(10 rows)
```

对比使用 Parallel Seq Scan 的查询：

```
EXPLAIN (analyze,buffers) SELECT * FROM example WHERE id > 100 AND id <= 2000;

                                                          QUERY PLAN
------------------------------------------------------------------------------------------------------------------------------
 Gather  (cost=1000.00..584334.60 rows=1 width=37) (actual time=1.751..1645.756 rows=1900 loops=1)
   Workers Planned: 2
   Workers Launched: 2
   Buffers: shared hit=16219 read=317115
   ->  Parallel Seq Scan on example  (cost=0.00..583334.50 rows=1 width=37) (actual time=1089.990..1635.938 rows=633 loops=3)
         Filter: ((id > 100) AND (id <= 2000))
         Rows Removed by Filter: 13332700
         Buffers: shared hit=16219 read=317115
 Planning Time: 0.659 ms
 Execution Time: 1646.008 ms
(10 rows)
```

### autovacuum 为什么也没用

上面一节提到了问题可能是 `AutoAacuumWork` 队列已满，但是日常运行的 `autovacuum` 也应该可以实现相同的效果，为什么也没用呢。为了方便测试，我们可单独将表运行 `autovacuum` 的相关阈值调低，其他保持则默认值：

```
ALTER TABLE example SET (autovacuum_vacuum_scale_factor = 0.0);
ALTER TABLE example SET (autovacuum_vacuum_threshold = 100);
```
然后根据我们的业务场景，不断在表中插入大量数据，然后观察 `pg_stat_user_tables` 中记录：

```
safeline=# SELECT * FROM pg_stat_user_tables where relname = 'example';

-[ RECORD 1 ]-------+------------------------------
relid               | 32824
schemaname          | public
relname             | example
seq_scan            | 81
seq_tup_read        | 202398405
idx_scan            | 5
idx_tup_fetch       | 198003205
n_tup_ins           | 110000010
n_tup_upd           | 0
n_tup_del           | 0
n_tup_hot_upd       | 0
n_live_tup          | 110000000
n_dead_tup          | 0
n_mod_since_analyze | 0
last_vacuum         |
last_autovacuum     |
last_analyze        |
last_autoanalyze    | xxxx-xx-xx 08:31:25.114953+00
vacuum_count        | 0
autovacuum_count    | 0
analyze_count       | 0
autoanalyze_count   | 3
```

发现 `last_autovacuum` 一直为空，而 `autoanalyze` 能够预期地按照一定频率运行。原来在 `do_autovacuum` 函数执行时，大致可分为 `dovacuum`、`doanalyze` 和 `doworkitems` 等过程，而其中的 `relation_needs_vacanalyze` 函数将判断关系表是否需要做 `vacuum` 或 `analyze`。在仅插入的场景下，表的 `n_dead_tup` 很小（本例中没有行被更新或删除，`n_dead_tup` 为 0），如果只调整 `autovacuum` 的运行频率等配置，`dovacuum` 也可能不会被触发。

> A table needs to be vacuumed if the number of dead tuples exceeds a threshold.  This threshold is calculated as
> 
> threshold = vac_base_thresh + vac_scale_factor * reltuples

当然，前面说明了 `autosummarize` 需要依赖 `do_autovacuum` 中的 `doworkitems` 来进行处理，如果 `autovacuum` 没有运行，则 `autosummarize` 也是无效的。

## Reference

\[1\]: [PostgreSQL中BRIN和BTREE索引的比较](https://mp.weixin.qq.com/s/4MF9yMzoJQdk0Qa4jw2xSQ)

\[2\]: [GitHub - brin_revmap.c](https://github.com/postgres/postgres/blob/322548a8abe225f2cfd6a48e07b99e2711d28ef7/src/backend/access/brin/brin_revmap.c#L197)

\[3\]: [GitHub - brin.c](https://github.com/postgres/postgres/blob/322548a8abe225f2cfd6a48e07b99e2711d28ef7/src/backend/access/brin/brin.c#L190)

\[4\]: [GitHub - autovacuum.c](https://github.com/postgres/postgres/blob/322548a8abe225f2cfd6a48e07b99e2711d28ef7/src/backend/postmaster/autovacuum.c#L2559)