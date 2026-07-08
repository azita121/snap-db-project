USE SnapProject;
GO

CREATE FUNCTION Food.fn_GetCustomerWallet
(
    @CustomerID INT
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @Balance DECIMAL(10,2);

    SELECT @Balance = WalletBalance
    FROM Food.Customer
    WHERE CustomerID = @CustomerID;

    RETURN ISNULL(@Balance,0);
END;
GO