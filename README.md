# BAKAY_MOVIELENS_DB


Tento repozitár obsahuje implementáciu ETL procesu v Snowflake pre analýzu dát z **MovieLens** datasetu. Projekt sa zameriava na preskúmanie správania používateľov a ich sledovacích preferencií na základe hodnotení filmov a demografických údajov používateľov. Výsledný dátový model umožňuje multidimenzionálnu analýzu a vizualizáciu kľúčových metrik.

---
## **1. Úvod a popis zdrojových dát**
Cieľom semestrálneho projektu je analyzovať dáta týkajúce sa filmov, používateľov a ich hodnotení. Táto analýza umožňuje identifikovať trendy v sledovacích preferenciách, najpopulárnejšie filmy a správanie používateľov.

Zdrojové dáta pochádzajú z datasetu dostupného [tu](https://grouplens.org/datasets/movielens/). Dataset obsahuje sedem hlavných tabuliek a jednu spojovaciu:
- `users`
- `age_group`
- `tags`
- `occupations`
- `ratings`
- `movies`
- `genres`
  
A spojovacia tabulka - `genre_movies`

Účelom ETL procesu bolo tieto dáta pripraviť, transformovať a sprístupniť pre viacdimenzionálnu analýzu.

---
### **1.1 Dátová architektúra**

### **ERD diagram**
Surové dáta sú usporiadané v relačnom modeli, ktorý je znázornený na **entitno-relačnom diagrame (ERD)**:


<p align="center">
  <img src="https://github.com/Marecko/BAKAY_MOVIELENS_DB/blob/main/MovieLens_ERD.png" alt="ERD Schema">
  <br>
  <em>Obrázok 1 Entitno-relačná schéma MovieLens</em>
</p>

---
## **2 Dimenzionálny model**

Navrhnutý bol **hviezdicový model (star schema)**, pre efektívnu analýzu kde centrálny bod predstavuje faktová tabuľka **`fact_ratings`**, ktorá je prepojená s nasledujúcimi dimenziami:
- **`dim_movie`**: Obsahuje podrobné informácie o knihách (názov, rok vydania, žáner).
- **`dim_users`**: Obsahuje demografické údaje o používateľoch, ako sú vekové kategórie, pohlavie, povolanie.
- **`dim_date`**: Zahrňuje informácie o dátumoch hodnotení (deň, mesiac, rok).

Štruktúra hviezdicového modelu je znázornená na diagrame nižšie. Diagram ukazuje prepojenia medzi faktovou tabuľkou a dimenziami, čo zjednodušuje pochopenie a implementáciu modelu.

<p align="center">

  <img src="https://github.com/Marecko/BAKAY_MOVIELENS_DB/blob/main/star_schema_MovieLens.png" alt="Star Schema">
  <br>
  <em>Obrázok 2 Schéma hviezdy pre MovieLens</em>
</p>

---
## **3. ETL proces v Snowflake**
ETL proces pozostával z troch hlavných fáz: `extrahovanie` (Extract), `transformácia` (Transform) a `načítanie` (Load). Tento proces bol implementovaný v Snowflake s cieľom pripraviť zdrojové dáta zo staging vrstvy do viacdimenzionálneho modelu vhodného na analýzu a vizualizáciu.

---
### **3.1 Extract (Extrahovanie dát)**
Dáta zo zdrojového datasetu (formát `.csv` alebo `.dat`) boli najprv nahraté do Snowflake prostredníctvom interného stage úložiska s názvom `my_stage`. Stage v Snowflake slúži ako dočasné úložisko na import alebo export dát. Tabulkám s menej záznammi boli dáta nahraté priamo

#### Príklad kódu:

```sql
CREATE OR REPLACE STAGE my_stage;
```
Do stage boli nahráne príslušné csv a dat súbory rating, movie, users, tags

```sql
COPY INTO movies_staging
FROM @my_stage/movies.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 0);
```

A priame pridanie hodnôt pre tabulky genre, age, occupation

```sql
INSERT INTO age_staging VALUES (1,'Under 18'),(18,'18-24'),(25,'25-34'),(35,'35-44'),(45,'45-49'),(50,'50-55'),(56,'56+');
```

### **3.1 Transfor (Transformácia dát)**

V tejto fáze boli dáta zo staging tabuliek vyčistené, transformované a obohatené. Hlavným cieľom bolo pripraviť dimenzie a faktovú tabuľku, ktoré umožnia jednoduchú a efektívnu analýzu.

Dimenzie boli navrhnuté na poskytovanie kontextu pre faktovú tabuľku. `dim_users` obsahuje údaje o používateľoch vrátane vekových kategórií, pohlavia, zamestnania. Transformácia zahŕňala rozdelenie veku používateľov do kategórií (napr. „18-24“) a pridanie popisov zamestnaní a pohlavia
```sql
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
```

Dimenzia `dim_movies` obsahuje údaje o názve filmu, roku vydania, a druhu žanru
```sql 
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
```

Dimenzia `dim_date` obsahuje údaje o čase, dni, mesiaci(Datum) hodnotenia.
```sql 
CREATE TABLE dim_date AS
SELECT
    ROW_NUMBER() OVER (ORDER BY CAST(rated_at AS DATE)) AS dim_dateID, 
    CAST(rated_at AS DATE) AS date,                                   
    DATE_PART(day, rated_at) AS day,                                  
    DATE_PART(dow, rated_at) + 1 AS dayOfWeek,                        
    CASE DATE_PART(dow, rated_at) + 1                                 
        WHEN 1 THEN 'Pondelok'
        WHEN 2 THEN 'Utorok'
        WHEN 3 THEN 'Streda'
        WHEN 4 THEN 'Štvrtok'
        WHEN 5 THEN 'Piatok'
        WHEN 6 THEN 'Sobota'
        WHEN 7 THEN 'Nedeľa'
    END AS dayOfWeekAsString,
    DATE_PART(month, rated_at) AS month,                              
    DATE_PART(year, rated_at) AS year,                                
    DATE_PART(quarter, rated_at) AS quarter                           
FROM ratings_staging;
```


Faktová tabuľka `fact_ratings` obsahuje záznamy o hodnoteniach a prepojenia na všetky dimenzie. Obsahuje kľúčové metriky, ako je hodnota hodnotenia.
```sql
CREATE TABLE FACT_RATINGS AS
SELECT 
    r.ratingId AS fact_ratingID,    -- Unikátne ID hodnotenia
    r.rating as rating,             -- Hodnota hodnotenia
    u.dim_userid as userID,         -- Prepojenie s dimenziou používateľov
    m.dim_movieId as movieID,       -- Prepojenie s dimenziou filmov
FROM ratings_staging as r
JOIN dim_movies as m ON m.dim_movieId = r.movieID   -- Prepojenie na základe filmu
JOIN dim_users as u ON u.dim_userId = r.userID;     -- Prepojenie na základe používateľa
```



---
## **4 Vizualizácia dát**
<p align="center">DashBoard Obsahuje 6 vizualizácií ktoré nám objasňujú určité metriky našich dát

  <img src="https://github.com/Marecko/BAKAY_MOVIELENS_DB/blob/main/grafy.png" alt="Grazy">
  <br>
  <em>Obrázok 3 ktoré nám objasňujú určité metriky našich dát </em>
</p>

---
### **Graf 1: Počty hodnotení filmov**
Táto vizualizácia zobrazuje počty hodnotení pre všetky filmy, vidíme že najčastejsie hodnotia používatelia filmy ratingom 3
ale hodnoty celočíselné 1,2,3,4,5 sú najčastejšie. Ludia taktiež skôr hodnotia pozitívne hodnotenie > 2,5(Neutrálny pocit z  filmu)

```sql
SELECT 
    m.title AS movie_title,
    ROUND(AVG(r.rating), 2) AS avg_rating,
FROM FACT_RATINGS r
JOIN DIM_MOVIES m ON r.movieID = m.dim_movieId
GROUP BY m.title
ORDER BY avg_rating DESC;
```

### **Graf 2: Počty hodnotení použivatelov (Podla vekevej kategorie)**
Táto vizualizácia zobrazuje počet hodnotení od používatelov rozdelené podla veku.
Vidíme že najviac hodnotení majú používatelia vo veku 25-34 a najmenej hodnotení majú skupiny Under 18 a 55+



```sql
SELECT 
    u.age_group AS age_group,
    COUNT(r.rating) AS total_ratings
FROM FACT_RATINGS r
JOIN DIM_USERS u ON r.userID = u.dim_userId
GROUP BY u.age_group
ORDER BY 
    CASE 
        WHEN u.age_group = 'Under 18' THEN 1
        WHEN u.age_group = '18-24' THEN 2
        WHEN u.age_group = '25-34' THEN 3
        WHEN u.age_group = '35-44' THEN 4
        WHEN u.age_group = '45-54' THEN 5
        WHEN u.age_group = '55+' THEN 6
        ELSE 7
    END;
```

### **Graf 3: Najpopulárnejšie žánre (Podla Počtu hodnotení)**
Táto vizualizácia zobrazuje počet hodnotení pre rozdielne žánre.
Najviac hodnotení má žáner Action a úplne nakonci je Documentary

```sql
SELECT 
    g.name AS genre,
    COUNT(r.rating) AS total_ratings
FROM FACT_RATINGS r
JOIN DIM_MOVIES m ON r.movieID = m.dim_movieId
JOIN genre_movies_staging gm ON gm.movieId = m.dim_movieId
JOIN genre_staging g ON g.genreId = gm.genreId
GROUP BY g.name
ORDER BY total_ratings DESC;
```


### **Graf 4: Najpopulárnejšie žánre (Podla Počtu filmov)**
Táto vizualizácia zobrazuje počet filmov pre rozdielne žánre
Najviac sa vydáva filmov žanru Drama a najmenej Film-Noir

```sql
SELECT 
    g.name AS genre,
    COUNT(r.rating) AS total_ratings
FROM FACT_RATINGS r
JOIN DIM_MOVIES m ON r.movieID = m.dim_movieId
JOIN genre_movies_staging gm ON gm.movieId = m.dim_movieId
JOIN genre_staging g ON g.genreId = gm.genreId
GROUP BY g.name
ORDER BY total_ratings DESC;
```




### **Graf 5: Priemerný počet hodnotení pre film (Podľa žanrov)**
V priemere sa najviac hodnotia filmy s žanrom Sci-Fi a najmenej v žanri Documentary
Taktiež si môžme porovnať výsledky s iným grafmi a uvidíme že napriek tomu, že Drama ma najviac filmov
tak v priemere má 237 hodnotení na film to ked porovnáme s Film-Noir ktorý má síce málo filmov 
ale priemerný počet hodnotení je až 415.


```sql
SELECT 
    g.name AS genre,
    COUNT(r.ratingId)/1000 AS total_ratings,
    COUNT(DISTINCT gm.movieId) AS total_movies,
    ROUND(COUNT(r.ratingId) * 1.0 / COUNT(DISTINCT gm.movieId), 2) AS avg_ratings_per_movie
FROM genre_staging g
JOIN genre_movies_staging gm ON g.genreId = gm.genreId
JOIN movies_staging m ON gm.movieId = m.movieId
JOIN ratings_staging r ON m.movieId = r.movieId
GROUP BY g.name
ORDER BY avg_ratings_per_movie DESC;
```


### **Graf 6: Priemerné hodnotenie podla vekovej skupiny**
Tento graf nám ukazuje priemernú hodnotu hodnotení podla vekovej skupiny. Hodnoty sa nelíšia významne,
Môžme teda usúdiť že vek nemá velký vplyv na náročnosť hodnotenia.

```sql
SELECT 
    u.age_group,
    ROUND(AVG(r.rating), 2) AS avg_rating
FROM FACT_RATINGS r
JOIN DIM_USERS u ON r.userID = u.dim_userId
GROUP BY u.age_group
ORDER BY avg_rating DESC;
```

Vytvoril: Marek Bakay
SNAIL_MOVIELENS_DB
https://app.snowflake.com/sfedu02/nib08201/w3NztVLoNXMW#query

