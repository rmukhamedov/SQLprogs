USE Mukhamedov_FARMS
GO


IF object_id('sp_UpdateResDetail') IS NOT NULL
DROP PROC sp_UpdateResDetail
GO

CREATE PROC sp_UpdateResDetail
	@RDID varchar(max) = NULL,
	@CheckinDate smalldatetime = NULL,
	@Nights tinyint = NULL,
	@RDStatus char(1) = NULL,
	@Error int = 0 OUTPUT
AS
BEGIN TRY
	SET @RDID = CONVERT(smallint, @RDID);
END TRY
BEGIN CATCH
	DECLARE @message varchar(max)
	SET @message = ('"' + @RDID + '" is not a valid Reservation Detail ID number. Please enter an integer.')
	RAISERROR (@message, -1, -1, @RDID)
	RETURN -1
END CATCH
IF @CheckinDate IS NOT NULL
	UPDATE RESERVATIONDETAIL
	SET CheckinDate = @CheckinDate
	FROM RESERVATIONDETAIL
	WHERE ReservationDetailID = @RDID;
IF @Nights IS NOT NULL
	UPDATE RESERVATIONDETAIL
	SET Nights = @Nights
	FROM RESERVATIONDETAIL
	WHERE ReservationDetailID = @RDID;
IF @RDStatus IS NOT NULL
	UPDATE RESERVATIONDETAIL
	SET RDStatus = @RDStatus
	FROM RESERVATIONDETAIL
	WHERE ReservationDetailID = @RDID;
GO

IF object_id('dbo.ProduceBill') IS NOT NULL
DROP FUNCTION dbo.ProduceBill
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

--1
IF EXISTS (SELECT * FROM sys.triggers WHERE name='tr_UpdateReservation')
DROP TRIGGER tr_UpdateReservation
GO

CREATE TRIGGER tr_UpdateReservation
ON RESERVATIONDETAIL
FOR UPDATE
AS
IF EXISTS
	(
	SELECT *
	FROM inserted i
	WHERE i.RDStatus = 'X'
	AND DATEDIFF(HOUR, GETDATE(), i.CheckinDate) <= 48
	)
BEGIN
	DECLARE @roomAmount smallmoney,
			@taxPercent decimal,
			@RDID		smallint

	SELECT @roomAmount = i.QuotedRate, @taxPercent = tr.RoomTaxRate, @RDID = i.ReservationDetailID
	FROM inserted i
	JOIN ROOM r
		ON r.RoomID = i.RoomID
	JOIN HOTEL h
		ON r.HotelID = h.HotelID
	JOIN TAXRATE tr
		ON tr.TaxLocationID = h.TaxLocationID
	WHERE i.RDStatus = 'X'
	AND DATEDIFF(HOUR, GETDATE(), i.CheckinDate) <= 48

	INSERT INTO RESERVATIONDETAILBILLING
	VALUES (@RDID, '1', 'Cancellation Room', @roomAmount, '1', GETDATE())

	INSERT INTO RESERVATIONDETAILBILLING
	VALUES (@RDID, '2', 'Cancellation Tax', (@roomAmount * @taxPercent)/100, '1', GETDATE())
END
IF EXISTS
	(
	SELECT *
	FROM inserted i
	WHERE i.RDStatus = 'B'
	)
BEGIN
	DECLARE @RDIDb smallint,
			@Nights decimal,
			@taxPercentb decimal,
			@roomAmountb smallmoney,
			@CheckinDate smalldatetime

	SELECT @roomAmountb = i.QuotedRate, @taxPercentb = tr.RoomTaxRate, @RDIDb = i.ReservationDetailID, @Nights = CONVERT(decimal, i.Nights)
	FROM inserted i
	JOIN ROOM r
		ON r.RoomID = i.RoomID
	JOIN HOTEL h
		ON r.HotelID = h.HotelID
	JOIN TAXRATE tr
		ON tr.TaxLocationID = h.TaxLocationID
	WHERE i.RDStatus = 'B'

	IF (DATEDIFF(HOUR, @CheckinDate + @Nights, GetDate()) >=16)
	SET @Nights = @Nights + 1
	ELSE IF (DATEDIFF(HOUR, @CheckinDate + @Nights, GetDate()) >=13)
	SET @Nights = @Nights + 0.5


	INSERT INTO RESERVATIONDETAILBILLING
	VALUES (@RDIDb, '1', 'Room', (@roomAmountb * @Nights), '1', GETDATE())

	INSERT INTO RESERVATIONDETAILBILLING
	VALUES (@RDIDb, '2', 'Tax', (@roomAmountb * @Nights * @taxPercentb)/100, '1', GETDATE())
END
GO

--2
IF EXISTS (SELECT * FROM sys.triggers WHERE name='tr_InsertRevenue')
DROP TRIGGER tr_InsertRevenue
GO

CREATE TRIGGER tr_InsertRevenue
ON RESERVATIONDETAILBILLING
FOR INSERT
AS
IF EXISTS
	(
	SELECT *
	FROM inserted i
	WHERE BillingCategoryID = '1'
	)
BEGIN
	DECLARE @RID smallint

	SELECT @RID = r.ReservationID
	FROM inserted i
	JOIN RESERVATIONDETAIL rd
	ON i.ReservationDetailID = rd.ReservationDetailID
	JOIN RESERVATION r
	ON rd.ReservationID = r.ReservationID
	WHERE BillingCategoryID = '1'

	PRINT dbo.ProduceBill(@RID)
END
GO

--3
EXECUTE sp_UpdateResDetail '8', NULL, NULL, 'B'
GO

--4
EXECUTE sp_UpdateResDetail '18', NULL, NULL, 'X'
GO

--5
SELECT * FROM RESERVATIONDETAILBILLING
GO

--6
IF EXISTS (SELECT * FROM sys.triggers WHERE name='tr_InsertReservationDetail')
DROP TRIGGER tr_InsertReservationDetail
GO

CREATE TRIGGER tr_InsertReservationDetail
ON RESERVATIONDETAIL
INSTEAD OF INSERT
AS 

INSERT INTO RESERVATIONDETAIL(RoomID, ReservationID, GuestID, QuotedRate, CheckinDate, Nights, RDStatus)
SELECT i.RoomID, i.ReservationID, i.GuestID, rt.RoomTypeRackRate, i.CheckinDate, i.Nights, i.RDStatus
FROM inserted i
JOIN ROOM r
ON i.RoomID = r.RoomID
JOIN HOTELROOMTYPE rt
ON r.HotelRoomTypeID = rt.HotelRoomTypeID

GO

--6b
INSERT INTO RESERVATIONDETAIL (RoomID, ReservationID, GuestID, QuotedRate, CheckinDate, Nights, RDStatus)
VALUES ('10', '5014', '1505', '1000', GETDATE() + 10, '3', 'A')
GO

SELECT * FROM RESERVATIONDETAIL