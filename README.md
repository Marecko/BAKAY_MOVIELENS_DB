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
- **`dim_users`**: Obsahuje demografické údaje o používateľoch, ako sú vekové kategórie, pohlavie, povolanie a vzdelanie.
- **`dim_date`**: Zahrňuje informácie o dátumoch hodnotení (deň, mesiac, rok).

Štruktúra hviezdicového modelu je znázornená na diagrame nižšie. Diagram ukazuje prepojenia medzi faktovou tabuľkou a dimenziami, čo zjednodušuje pochopenie a implementáciu modelu.

<p align="center">![star_schema_MovieLens](https://github.com/user-attachments/assets/55c6ac64-c17c-4ef2-910c-15300545f4f1)

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
