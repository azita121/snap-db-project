USE SnapProject;
GO

CREATE TRIGGER Food.trg_UpdateRestaurantWallet
ON Food.FoodPayment
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE r
    SET r.WalletBalance = r.WalletBalance + i.Amount
    FROM Food.Restaurant r
    INNER JOIN Food.CustomerOrder o
        ON r.RestaurantID = o.RestaurantID
    INNER JOIN inserted i
        ON o.OrderID = i.OrderID
    WHERE i.PaymentStatus = 'Paid';
END;
GO