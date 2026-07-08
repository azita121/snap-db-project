USE SnapProject;
GO

CREATE TRIGGER Ride.trg_PreventNegativeDriverWallet
ON Ride.Driver
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted
        WHERE WalletBalance < 0
    )
    BEGIN
        RAISERROR('Driver wallet balance cannot be negative.',16,1);
        ROLLBACK TRANSACTION;
    END
END;
GO