USE [SnapProject]
GO

/****** Object:  UserDefinedFunction [Ride].[fn_GetPassengerWallet]    Script Date: 7/13/2026 5:52:43 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE FUNCTION [Ride].[fn_GetPassengerWallet]
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


