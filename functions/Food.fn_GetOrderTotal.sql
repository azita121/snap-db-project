USE SnapProject;
GO

CREATE FUNCTION Food.fn_GetOrderTotal
(
    @OrderID INT
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @Total DECIMAL(10,2);

    SELECT @Total = SUM(Quantity * UnitPrice)
    FROM Food.OrderItem
    WHERE OrderID = @OrderID;

    RETURN ISNULL(@Total, 0);
END;
GO