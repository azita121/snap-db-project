USE SnapProject;
GO

CREATE TRIGGER Food.trg_PreventNegativeWallet
ON Food.Customer
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted
        WHERE WalletBalance < 0
    )
    BEGIN
        RAISERROR ('Customer wallet balance cannot be negative.',16,1);
        ROLLBACK TRANSACTION;
    END
END;
GO