USE [SnapProject]
GO

/****** Object:  UserDefinedFunction [Ride].[fn_GetDriverWallet]    Script Date: 7/13/2026 5:42:23 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE FUNCTION [Ride].[fn_GetDriverWallet]
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


