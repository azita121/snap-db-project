USE SnapProject;
GO

CREATE PROCEDURE Food.sp_UpdateCustomerWallet
    @CustomerID INT,
    @Amount DECIMAL(10,2)
AS
BEGIN
    UPDATE Food.Customer
    SET WalletBalance = WalletBalance + @Amount
    WHERE CustomerID = @CustomerID;
END;
GO