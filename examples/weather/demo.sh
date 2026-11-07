#!/usr/bin/env bash
# weather demo —— observe→auto 全流程模拟（无外部依赖，无凭据）
# 用法: bash demo.sh --observe | --auto
set -euo pipefail
MODE="${1:---observe}"

# 内置三天"天气数据"（真实接入时来自你的天气 API 轮询）
EVENTS=(
  "第一天|晴|28°"
  "第二天|小雨|22°"
  "第三天|暴雨预警|19°"
)

# 闸门规则（真实部署写在 policy 里）：只有暴雨预警值得开工单
rule_matches() { [[ "$2" == *"暴雨"* ]]; }

echo "== weather demo：模式=$MODE =="
echo "   observe 档只记录 would_trigger，不执行；auto 档直接触发。"
echo ""

for e in "${EVENTS[@]}"; do
  IFS='|' read -r day cond temp <<<"$e"
  if rule_matches "$day" "$cond"; then
    if [[ "$MODE" == "--auto" ]]; then
      echo "  [$day] $cond($temp) → ✅ 触发：工单已开（title: 提醒收衣服/关窗）"
    else
      echo "  [$day] $cond($temp) → 👁 would_trigger（已记录，不执行——observe 档）"
    fi
  else
    echo "  [$day] $cond($temp) → ⏭ skip（规则不匹配，不吵任何人）"
  fi
done

echo ""
if [[ "$MODE" == "--observe" ]]; then
  echo "== 对账要点：would_trigger 的记录与你的判断一致（无多报漏报），才切 --auto =="
else
  echo "== 回滚方式：改回 --observe 即停手，无需重启 =="
fi
