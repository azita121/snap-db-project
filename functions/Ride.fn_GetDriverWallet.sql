USE SnapProject;
GO

CREATE FUNCTION Ride.fn_GetDriverWallet
(
    @DriverID INT
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @Balance DECIMAL(10,2);

    SELECT @Balance = WalletBalance
    FROM Ride.Driver
    WHERE DriverID = @DriverID;

    RETURN ISNULL(@Balance,0);
END;
GO