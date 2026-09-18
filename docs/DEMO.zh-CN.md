# MoonQuery 三分钟演示脚本

## 0:00—0:30 定位

打开 README 的边界表：`shunge/arrow` 负责 Arrow 数据和 IPC，MoonQuery 负责查询。
指出 `moon.mod` 的直接依赖，以及生产代码只有 `src/query`，没有重复格式实现。

## 0:30—1:10 展示查询计划

运行：

```sh
moon run cmd/main --target native
```

解释计划：先筛选销量大于 2 且 active 为 true 的订单，然后按区域分组计算收入合计
和订单数，按收入降序排列，最后限制结果行数。

## 1:10—1:50 展示正确结果

程序应显示：

```text
Result rows: 2
  region=East, revenue_sum=320, orders=2
  region=null, revenue_sum=null, orders=1
```

第二行用于证明 null key 会形成独立分组、全 null SUM 返回 null，而 COUNT 仍为 1。

## 1:50—2:20 展示生态衔接

程序把查询结果交给 `shunge/arrow.write_stream`，再通过 `read_stream` 回读。这里强调：
MoonQuery 没有重新实现 IPC，而是作为现有 Arrow 模块的真实下游消费者。

## 2:20—3:00 展示质量证据

```sh
moon check --target all --deny-warn
moon test --target all --deny-warn
```

说明测试覆盖四后端，以及查询计划、三值逻辑、排序、分组、Join、错误处理和 IPC
交接。最后打开 `docs/DIFFERENTIATION.zh-CN.md`，展示代码级边界清单。
