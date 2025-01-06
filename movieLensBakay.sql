-- Vytvorenie databázy
CREATE DATABASE SNAIL_MovieLens_DB;

-- Vytvorenie schémy pre staging tabuľky
CREATE SCHEMA SNAIL_MovieLens_DB.staging;



USE SCHEMA SNAIL_MovieLens_DB.staging;

DROP TABLE users_staging;
-- Vytvorenie tabuľky users (staging)
CREATE TABLE users_staging (
    userId INT PRIMARY KEY,
    gender VARCHAR,
    age INT,
    occupationId INT,
    zip_code VARCHAR,
    FOREIGN KEY (occupationId) REFERENCES occupation_staging(occupationId),
    FOREIGN KEY (age) REFERENCES age_staging(ageId)
);


-- Vytvorenie tabuľky occupation (staging)
CREATE TABLE occupation_staging (
    occupationId INT PRIMARY KEY,
    name VARCHAR(255)
);

-- Vytvorenie tabuľky age (staging)
CREATE TABLE age_staging (
    ageId INT PRIMARY KEY,
    name VARCHAR(45)
);


-- Vytvorenie tabuľky tags (staging)
CREATE TABLE tags_staging (
    tagsId INT PRIMARY KEY ,
    userId INT,
    movieId INT,
    tags VARCHAR(400),
    created_at DATE
);

-- Vytvorenie tabuľky ratings (staging)
CREATE TABLE ratings_staging (
    ratingId INT PRIMARY KEY AUTOINCREMENT,
    userId INT,
    movieId INT,
    rating INT,
    FOREIGN KEY (userId) REFERENCES users_staging(userId),
    FOREIGN KEY (movieId) REFERENCES movies_staging(movieId)
);



-- Vytvorenie tabuľky movies (staging)
CREATE TABLE movies_staging(
    movieId INT PRIMARY KEY,
    title VARCHAR(255),
    release_year CHAR(4)
);
-- Vytvorenie tabuľky genre_movies (staging)
CREATE TABLE genre_movies_staging (
    g_mId INT PRIMARY KEY,
    movieId INT,
    genreId INT,
    FOREIGN KEY (genreId) REFERENCES genre_staging(genreId),
    FOREIGN KEY (movieId) REFERENCES movies_staging(movieId)
);


-- Vytvorenie tabuľky genre (staging)
CREATE TABLE genre_staging(
    genreId INT PRIMARY KEY,
    name VARCHAR(255)
);





CREATE OR REPLACE STAGE my_stage;

INSERT INTO genre_staging VALUES (1,'Action'),(2,'Adventure'),(3,'Animation'),(4,'Children\'s'),(5,'Comedy'),(6,'Crime'),(7,'Documentary'),(8,'Drama'),(9,'Fantasy'),(10,'Film-Noir'),(11,'Horror'),(12,'Musical'),(13,'Mystery'),(14,'Romance'),(15,'Sci-Fi'),(16,'Thriller'),(17,'War'),(18,'Western');

INSERT INTO age_staging VALUES (1,'Under 18'),(18,'18-24'),(25,'25-34'),(35,'35-44'),(45,'45-49'),(50,'50-55'),(56,'56+');

COPY INTO genre_movies_staging
FROM @my_stage/genres_movies.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

COPY INTO movies_staging
FROM @my_stage/movies.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 0);

INSERT INTO occupation_staging VALUES (0,'Others/Not Specified'),(1,'Administrator'),(2,'Artist'),(3,'Doctor'),(4,'Educator'),(5,'Engineer'),(6,'Entertainment'),(7,'Executive'),(8,'Healthcare'),(9,'Homemaker'),(10,'Lawyer'),(11,'Librarian'),(12,'Marketing'),(13,'None'),(14,'Other'),(15,'Programmer'),(16,'Retired'),(17,'Salesman'),(18,'Scientist'),(19,'Student'),(20,'Technician'),(21,'Writer');

COPY INTO ratings_staging (userId, movieId, rating)
FROM @my_stage/cleaned_file.dat
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' FIELD_DELIMITER = '::');

COPY INTO tags_staging
FROM @my_stage/tags.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 0);


COPY INTO users_staging(userId,gender,age,occupationId,zip_code)
FROM @my_stage/users.dat
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' FIELD_DELIMITER = '::');


--- ELT - (T)ransform
-- dim_users
CREATE TABLE dim_users AS
SELECT DISTINCT
    u.userId AS dim_userId,
    CASE 
        WHEN u.age < 18 THEN 'Under 18'
        WHEN u.age BETWEEN 18 AND 24 THEN '18-24'
        WHEN u.age BETWEEN 25 AND 34 THEN '25-34'
        WHEN u.age BETWEEN 35 AND 44 THEN '35-44'
        WHEN u.age BETWEEN 45 AND 54 THEN '45-54'
        WHEN u.age >= 55 THEN '55+'
        ELSE 'Unknown'
    END AS age_group,
    CASE
        WHEN u.gender = 'F' THEN 'FEMALE'
        WHEN u.gender = 'M' THEN 'MALE'
        ELSE 'Unknown'
    END AS gender,
    o.name AS occupation,
FROM users_staging as u
JOIN age_staging as a ON u.age = a.ageId
JOIN occupation_staging as o ON o.occupationId = u.occupationId;



-- dim_movies
CREATE TABLE DIM_MOVIES AS
SELECT DISTINCT
    m.movieId AS dim_movieId,      
    m.title AS title,       
    m.release_year AS release_year,     
    g.name AS Genre
FROM movies_staging as m
JOIN genre_movies_staging as gm ON m.movieId = gm.movieId
JOIN genre_staging as g ON gm.genreId = g.genreId;


CREATE TABLE FACT_RATINGS AS
SELECT 
    r.ratingId AS fact_ratingID,    -- Unikátne ID hodnotenia
    r.rating as rating,             -- Hodnota hodnotenia
    u.dim_userid as userID,         -- Prepojenie s dimenziou používateľov
    m.dim_movieId as movieID,       -- Prepojenie s dimenziou filmov
FROM ratings_staging as r
JOIN dim_movies as m ON m.dim_movieId = r.movieID   -- Prepojenie na základe filmu
JOIN dim_users as u ON u.dim_userId = r.userID;     -- Prepojenie na základe používateľa



