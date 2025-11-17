#!/bin/bash

OUTPUT_FILE="lambda_reserved_concurrency.csv"

# Clear/create the output file
echo "FunctionName,ReservedConcurrentExecutions" > $OUTPUT_FILE

TOTAL=0

# Loop through all Lambda functions
aws lambda list-functions --query "Functions[].FunctionName" --output json \
| jq -r '.[]' \
| while read fname; do
    # Get reserved concurrency
    result=$(aws lambda get-function-concurrency \
        --function-name "$fname" \
        --query "ReservedConcurrentExecutions" \
        --output text 2>/dev/null)
    
    # Only if ReservedConcurrency is set
    if [[ "$result" != "None" && "$result" != "" ]]; then
        echo "$fname,$result" >> $OUTPUT_FILE
        TOTAL=$((TOTAL + result))
    fi
done

# Wait a bit to ensure TOTAL is calculated (because while loop runs in a subshell)
sleep 1

# Append total at the end
echo "TOTAL,$TOTAL" >> $OUTPUT_FILE

echo "Done! CSV report saved to $OUTPUT_FILE"
