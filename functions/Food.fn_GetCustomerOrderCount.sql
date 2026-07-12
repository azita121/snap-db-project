USE SnapProject;
GO

CREATE FUNCTION Food.fn_GetCustomerOrderCount
(
    @CustomerID INT
)
RETURNS INT
AS
BEGIN
    DECLARE @OrderCount INT;

    SELECT @OrderCount = COUNT(*)
    FROM Food.CustomerOrder
    WHERE CustomerID = @CustomerID;

    RETURN ISNULL(@OrderCount, 0);
END;
GO