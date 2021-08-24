-- 1. Load data
---- Create the new database if it does not exist already
USE master -- execute from master database
GO

IF NOT EXISTS (
    SELECT *
        FROM sys.databases
        WHERE name = 'DataCleaningTutorial'
)
CREATE DATABASE DataCleaningTutorial
USE DataCleaningTutorial
GO

---- Create table
DROP TABLE IF EXISTS NashvilleHousing;
CREATE TABLE NashvilleHousing (
    UniqueID INT PRIMARY KEY,
    ParcelID VARCHAR(255),
    LandUse VARCHAR(255),
    PropertyAddress VARCHAR(255),
    SaleDate VARCHAR(255),
    SalePrice VARCHAR(255),
    LegalReference VARCHAR(255),
    SoldAsVacant VARCHAR(255),
    OwnerName VARCHAR(255),
    OwnerAddress VARCHAR(255),
    Acreage DECIMAL,
    TaxDistrict VARCHAR(255),
    LandValue INT,
    BuildingValue INT,
    TotalValue INT,
    YearBuilt INT,
    Bedrooms INT,
    FullBath INT,
    HalfBath INT
)
GO

---- Read CSV
BULK INSERT NashvilleHousing FROM '/data.csv'
WITH
(
    FORMAT = 'CSV',
    FIRSTROW = 2,               -- Skip CSV header row
    -- FIELDTERMINATOR = ',',   -- Redundant
    -- ROWTERMINATOR = '\n',    -- Redundant
    -- TABLOCK,                 -- Redundant
    KEEPNULLS                   -- Treat empty fields as NULLs
)

---- Confirm data is loaded into table
SELECT TOP 10 * 
FROM NashvilleHousing

-- 2. Standardize Date Format
---- Preview converting SaleDate to DATE
SELECT TOP 10 SaleDate, CONVERT(DATE, SaleDate)
FROM NashvilleHousing

---- Convert SaleDate to DATE
UPDATE NashvilleHousing 
SET SaleDate = CONVERT(DATE, SaleDate)

---- Confirm SaleDate is converted to DATE
SELECT TOP 10 SaleDate 
FROM NashvilleHousing

-- 3. Populate Property Address data
---- Select rows without PropertyAddress
SELECT TOP 10 ParcelID, PropertyAddress
FROM NashvilleHousing
WHERE PropertyAddress IS NULL

---- Select pairs of rows {a, b} where ParcelID are the same
---- where a's PropertyAddress is NULL and b's is NOT NULL
---- Preview replacing a's PropertyAddress  with b's
SELECT TOP 10 a.ParcelID, a.PropertyAddress, b.ParcelID, b.PropertyAddress, ISNULL(a.PropertyAddress, b.PropertyAddress)  
FROM NashvilleHousing a
JOIN NashvilleHousing b
    ON a.ParcelID = b.ParcelID
WHERE a.PropertyAddress IS NULL
    AND b.PropertyAddress IS NOT NULL

---- Update a's PropertyAddress with the b's PropertyAddress
UPDATE a
SET PropertyAddress = ISNULL(a.PropertyAddress,b.PropertyAddress)
FROM NashvilleHousing a
JOIN NashvilleHousing b
        ON a.ParcelID = b.ParcelID
        AND a.[UniqueID] <> b.[UniqueID]
WHERE a.PropertyAddress IS NULL

---- Confirm now all rows have PropertyAddress
SELECT TOP 10 ParcelID, PropertyAddress
FROM NashvilleHousing
WHERE PropertyAddress IS NULL

-- 4. Break PropertyAddress into columns (Address, City)
---- Preview columns to add
SELECT TOP 10
PropertyAddress,
SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) - 1),
SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) + 1, LEN(PropertyAddress))
FROM NashvilleHousing

---- Add PropertySplitAddress and PropertySplitCity columns
ALTER TABLE NashvilleHousing
ADD PropertySplitAddress VARCHAR(255);
GO

UPDATE NashvilleHousing
SET PropertySplitAddress = SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) -1 )

ALTER TABLE NashvilleHousing
ADD PropertySplitCity VARCHAR(255)
GO

UPDATE NashvilleHousing
SET PropertySplitCity = SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) + 1 , LEN(PropertyAddress))

---- Confirm columns are added
SELECT TOP 10 PropertyAddress, PropertySplitAddress, PropertySplitCity 
FROM NashvilleHousing

-- 5. Break OwnerAddress into columns (Address, City, State)
---- Preview columns to add
SELECT TOP 10
OwnerAddress,
PARSENAME(REPLACE(OwnerAddress, ',', '.') , 3),
PARSENAME(REPLACE(OwnerAddress, ',', '.') , 2),
PARSENAME(REPLACE(OwnerAddress, ',', '.') , 1)
FROM NashvilleHousing

---- Add OwnerSplitAddress, OwnerSplitCity, and OwnerSplitState columns
ALTER TABLE NashvilleHousing
ADD OwnerSplitAddress VARCHAR(255)
GO

Update NashvilleHousing
SET OwnerSplitAddress = PARSENAME(REPLACE(OwnerAddress, ',', '.') , 3)

ALTER TABLE NashvilleHousing
ADD OwnerSplitCity VARCHAR(255)
GO

Update NashvilleHousing
SET OwnerSplitCity = PARSENAME(REPLACE(OwnerAddress, ',', '.') , 2)

ALTER TABLE NashvilleHousing
ADD OwnerSplitState VARCHAR(255)
GO

Update NashvilleHousing
SET OwnerSplitState = PARSENAME(REPLACE(OwnerAddress, ',', '.') , 1)

---- Confirm columns are added
SELECT TOP 10 OwnerAddress, OwnerSplitAddress, OwnerSplitCity, OwnerSplitState 
FROM NashvilleHousing

-- 6. Change Y and N to Yes and No in "Sold as Vacant" field
---- Select current SoldAsVacant values
SELECT Distinct(SoldAsVacant), Count(SoldAsVacant)
FROM NashvilleHousing
GROUP BY SoldAsVacant

---- Preview updating 'Y' and 'N' to 'Yes' and 'No'
SELECT TOP 10 SoldAsVacant, 
    CASE WHEN SoldAsVacant = 'Y' THEN 'Yes'
        WHEN SoldAsVacant = 'N' THEN 'No'
        ELSE SoldAsVacant
    END
FROM NashvilleHousing
WHERE SoldAsVacant = 'Y' OR SoldAsVacant = 'N'

---- Update 'Y' and 'N' to 'Yes' and 'No''
UPDATE NashvilleHousing
SET SoldAsVacant = 
    CASE WHEN SoldAsVacant = 'Y' THEN 'Yes'
        WHEN SoldAsVacant = 'N' THEN 'No'
        ELSE SoldAsVacant
    END

---- Confirm 'Y' and 'N' have been replaced
SELECT Distinct(SoldAsVacant), Count(SoldAsVacant)
FROM NashvilleHousing
GROUP BY SoldAsVacant

-- 7. Remove Duplicates
---- View duplicate rows with CTE
;WITH RowCntCTE AS(  -- WITH needs the previous statement to end with ;
    SELECT ROW_NUMBER() OVER (
        PARTITION BY 
            ParcelID,
            PropertyAddress,
            SalePrice,
            SaleDate,
            LegalReference
            ORDER BY UniqueID
        ) row_cnt, *
    FROM NashvilleHousing
)
SELECT TOP 10 *
FROM RowCntCTE
WHERE row_cnt > 1

---- Remove duplicate rows
;WITH RowCntCTE AS(
    SELECT ROW_NUMBER() OVER (
        PARTITION BY 
            ParcelID,
            PropertyAddress,
            SalePrice,
            SaleDate,
            LegalReference
            ORDER BY UniqueID
        ) row_cnt, *
    FROM NashvilleHousing
)
DELETE
FROM RowCntCTE
WHERE row_cnt > 1

---- Confirm duplicate rows have been removed
;WITH RowCntCTE AS(
    SELECT ROW_NUMBER() OVER (
        PARTITION BY 
            ParcelID,
            PropertyAddress,
            SalePrice,
            SaleDate,
            LegalReference
            ORDER BY UniqueID
        ) row_cnt, *
    FROM NashvilleHousing
)
SELECT TOP 10 *
FROM RowCntCTE
WHERE row_cnt > 1

-- 8. Delete Unused Columns
---- View table and determine columns to drop
SELECT TOP 10 * 
FROM NashvilleHousing

---- Drop unused columns
ALTER TABLE NashvilleHousing
DROP COLUMN OwnerAddress, TaxDistrict, PropertyAddress

---- View final table
SELECT * 
FROM NashvilleHousing
