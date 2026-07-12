USE SnapProject;
GO

CREATE PROCEDURE Food.sp_UpdateOrderStatus
    @OrderID INT,
    @Status NVARCHAR(20)
AS
BEGIN
    UPDATE Food.CustomerOrder
    SET Status = @Status
    WHERE OrderID = @OrderID;
END;
GO