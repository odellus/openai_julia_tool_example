using ModelContextProtocol

calculator_tool = MCPTool(
    name = "calculate_tip",
    description = "Calculate tip amount and total bill",
    parameters = [
        ToolParameter(
            name = "bill_amount",
            description = "The bill amount in dollars",
            type = "number",
            required = true
        ),
        ToolParameter(
            name = "tip_percentage",
            description = "The tip percentage (default: 15.0)",
            type = "number",
            required = false,
            default = 15.0
        )
    ],
    handler = function(params)
        bill_amount = Float64(params["bill_amount"])
        tip_percentage = Float64(get(params, "tip_percentage", 15.0))

        tip_amount = bill_amount * (tip_percentage / 100)
        total_amount = bill_amount + tip_amount

        result_text = """
        Tip Calculation:
        - Bill Amount: \$$(round(bill_amount, digits=2))
        - Tip Percentage: $(tip_percentage)%
        - Tip Amount: \$$(round(tip_amount, digits=2))
        - Total Amount: \$$(round(total_amount, digits=2))
        """

        return TextContent(text = result_text)
    end
)
