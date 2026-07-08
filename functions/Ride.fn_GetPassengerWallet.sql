USE SnapProject;
GO

CREATE FUNCTION Ride.fn_GetPassengerWallet
(
    @PassengerID INT
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @Balance DECIMAL(10,2);

    SELECT @Balance = WalletBalance
    FROM Ride.Passenger
    WHERE PassengerID = @PassengerID;

    RETURN ISNULL(@Balance, 0);
END;
GO