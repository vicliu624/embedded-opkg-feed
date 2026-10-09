# TDVP cJSON

本配方构建 cJSON 1.7.19，版本 `1.7.19-2` 包含 TDVP 的 JSON Pointer
索引边界补丁。十进制索引累加前检查 `size_t` 溢出，空索引被拒绝。
基础解析库与 utilities 库一起交付，保留上游公开 API。

`cJSONUtils_ApplyPatches` 及其大小写敏感版本会修改传入文档。上游
明确说明失败时不保证原子性。需要事务语义的应用，应先复制文档，
对副本应用补丁，成功后提交副本；失败时删除副本并保留原对象。
可参考上游 `cJSON_Utils.h` 的说明及
`tests/cjson-atomic-wrapper-contract.c` 的完整错误处理测试。

包装代码必须处理复制分配失败，输入大小与深度也应限制。上游
`CJSON_NESTING_LIMIT` 约束解析深度，应用自行拼接树或应用补丁可能
产生不同的深度；解析测试通过不代表所有递归操作都安全。

当前已有目标边界、包装用法和上游 22 项测试证据。其他公开安全
公告仍在核对，不能把本补丁描述为全部 cJSON 漏洞已经修复。

来源：

- [上游 1.7.19 变更记录](https://github.com/DaveGamble/cJSON/blob/v1.7.19/CHANGELOG.md)
- [utilities 接口与原子包装说明](https://github.com/DaveGamble/cJSON/blob/v1.7.19/cJSON_Utils.h)
