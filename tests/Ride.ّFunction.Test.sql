USE SnapProject;
GO

PRINT 'Testing Ride Functions';
GO

SELECT Ride.fn_GetDriverWallet(1) AS DriverWallet;
GO

SELECT Ride.fn_GetPassengerWallet(1) AS PassengerWallet;
GO

SELECT Ride.fn_GetTripCount(1) AS TripCount;
GO