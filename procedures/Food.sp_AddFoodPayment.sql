USE SnapProject;
GO

CREATE PROCEDURE Food.sp_AddFoodPayment
    @OrderID INT,
    @Amount DECIMAL(10,2),
    @PaymentMethod NVARCHAR(20),
    @PaymentStatus NVARCHAR(20)
AS
BEGIN
    INSERT INTO Food.FoodPayment
    (
        OrderID,
        Amount,
        PaymentMethod,
        PaymentStatus
    )
    VALUES
    (
        @OrderID,
        @Amount,
        @PaymentMethod,
        @PaymentStatus
    );
END;
GO