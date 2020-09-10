USE Mukhamedov_FARMS
GO

SELECT * FROM GUEST
GO

CREATE FUNCTION dbo.ProduceBill(@ReservationID smallint)
RETURNS varchar(max)
AS
BEGIN
	
	DECLARE @RoomNo int = NULL,
			@Checkin smalldatetime = NULL,
			@Checkout smalldatetime = NULL,
			@ReservationDID smallint,
			@HotelName varchar(max),
			@Charge smallmoney,
			@Tax smallmoney,
			@Total smallmoney,
			@Name varchar(max),
			@Address varchar(max),
			@bill varchar(max),
			@pm	varchar(max);

	SELECT DISTINCT @Name = GuestFirst + ' ' + GuestLast, @Address = GuestAddress1 + ', ' + GuestCity
	FROM Guest g
	JOIN RESERVATIONDETAIL r
	ON r.GuestID = g.GuestID
	WHERE r.ReservationID = @ReservationID


	IF @Name IS NOT NULL AND @Address IS NOT NULL
		SET @bill = 'Master Reservation: ' + CONVERT(varchar, @ReservationID) + CHAR(13) + @Name + '    ' + @Address + CHAR(13) + CHAR(13)
	ELSE
		SET @bill = 'Master Reservation: ' + CONVERT(varchar, @ReservationID) + CHAR(13) + CHAR(13)
	DECLARE c1 CURSOR FOR 
		SELECT HotelName,  RoomNumber, CheckinDate, CheckinDate + Nights AS CheckoutDate, ReservationDetailID
		FROM RESERVATIONDETAIL rd
		JOIN ROOM r
		ON r.RoomID = rd.RoomID
		JOIN HOTEL h
		ON h.HotelID = r.HotelID
		WHERE ReservationID = @ReservationID
	OPEN c1
		FETCH NEXT FROM c1 INTO @HotelName, @RoomNo, @Checkin, @Checkout, @ReservationDID
		IF @RoomNo IS NULL
			RETURN 'No details found for this reservation'
		ELSE
			SET @pm = 'Reservation Details' + CHAR(13)
			WHILE @@FETCH_STATUS = 0 BEGIN

			
			SELECT @Charge = SUM(BillingAmount)
			FROM RESERVATIONDETAILBILLING
			WHERE ReservationDetailID = @ReservationDID
			AND NOT BillingDescription LIKE '%Tax%'

			SELECT @Tax = SUM(BillingAmount)
			FROM RESERVATIONDETAILBILLING
			WHERE ReservationDetailID = @ReservationDID
			AND BillingDescription LIKE '%Tax%'

			IF @Charge IS NOT NULL AND @Tax IS NOT NULL
			BEGIN
				SET @Total = @Total + @Charge + @Tax
				SET @pm = (@pm + 'Hotel Name: ' + @HotelName + 'Room Number: ' + CONVERT(varchar, @RoomNo) + '    Check-in Date: '+  CONVERT(varchar, @Checkin) + '    Check-out Date: ' + CONVERT(varchar, @Checkout) + '    Total Charge: $' + CONVERT(varchar, @Charge) + '    Total Tax: $' + CONVERT(varchar, @Tax));
			END
			ELSE
				SET @pm = (@pm + 'Hotel Name: ' + @HotelName + 'Room Number: ' + CONVERT(varchar, @RoomNo) + '    Check-in Date: '+  CONVERT(varchar, @Checkin) + '    Check-out Date: ' + CONVERT(varchar, @Checkout))
			SET @bill = @bill + @pm + CHAR(13) + CHAR(13)
			FETCH NEXT FROM c1 INTO @HotelName, @RoomNo, @Checkin, @Checkout, @ReservationDID
		END
	CLOSE c1
	DEALLOCATE c1
	RETURN @bill
END
GO

PRINT dbo.ProduceBill(5001)
PRINT dbo.ProduceBill(5002)
GO

CREATE FUNCTION dbo.AnticipatedRevenue(@Date1 smalldatetime, @Date2 smalldatetime)
RETURNS @Report Table
(
HotelID smallint NULL,
TRevenue smallmoney NULL,
TTax smallmoney NULL,
Error varchar(max) NULL
)
AS
BEGIN
DECLARE @ERROR varchar(max)
IF (@Date1 > @Date2)
BEGIN
	SET @ERROR = 'Not a valid date range'
	INSERT INTO @Report(Error)
	VALUES(@ERROR)
END
ELSE
INSERT INTO @Report
	SELECT HotelID, SUM(QuotedRate * Nights), SUM(QuotedRate * Nights * .035), NULL
	FROM RESERVATIONDETAIL rd
	JOIN ROOM r
	ON r.RoomID = rd.RoomID
	WHERE CheckinDate + Nights < @Date2
	GROUP BY HotelID
RETURN
END
GO

SELECT * FROM dbo.AnticipatedRevenue('03/01/2015', '03/31/2015')
SELECT * FROM dbo.AnticipatedRevenue( '03/31/2015', '03/01/2015')