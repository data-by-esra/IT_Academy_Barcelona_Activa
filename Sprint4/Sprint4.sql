#LEVEL 1

CREATE DATABASE sprintstar;

CREATE TABLE companies (
    company_id VARCHAR(100) PRIMARY KEY,
    company_name VARCHAR(100),
    phone VARCHAR(50),
    email VARCHAR(100),
    country VARCHAR(100),
    website VARCHAR(100)
);

LOAD DATA LOCAL INFILE '/Users/esrakesken/barcelona_activa/companies.csv' 
INTO TABLE companies
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;



CREATE TABLE IF NOT EXISTS credit_cards (
     id VARCHAR(20) PRIMARY KEY,
     user_id INT,
     iban VARCHAR(50) ,
     pan VARCHAR(19),
     pin VARCHAR(4),
     cvv VARCHAR(4),
     track1 VARCHAR(255),
     track2 VARCHAR(255),
     expiring_date VARCHAR(20)
     );

LOAD DATA LOCAL INFILE '/Users/esrakesken/barcelona_activa/credit_cards.csv' 
INTO TABLE credit_cards
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;     


CREATE TABLE IF NOT EXISTS products (
	 id INT PRIMARY KEY,
     product_name VARCHAR(50),
     price DECIMAL(10,2),
     colour VARCHAR(20),
     weight FLOAT,
     warehouse_id VARCHAR(25)
);

LOAD DATA LOCAL INFILE '/Users/esrakesken/barcelona_activa/products (1).csv' 
INTO TABLE products
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(id, product_name, @price, colour, weight, warehouse_id)
SET price = REPLACE(@price, '$', ''); 



CREATE TABLE IF NOT EXISTS european_users (
	id INT PRIMARY KEY,
	name VARCHAR(100),
	surname VARCHAR(100),
	phone VARCHAR(150),
	email VARCHAR(150),
	birth_date VARCHAR(100),
	country VARCHAR(150),
	city VARCHAR(150),
	postal_code VARCHAR(100),
	address VARCHAR(255)    
); 

LOAD DATA LOCAL INFILE '/Users/esrakesken/barcelona_activa/european_users.csv' 
INTO TABLE european_users
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS; 


CREATE TABLE IF NOT EXISTS american_users (
	id INT PRIMARY KEY,
	name VARCHAR(100),
	surname VARCHAR(100),
	phone VARCHAR(150),
	email VARCHAR(150),
	birth_date VARCHAR(100),
	country VARCHAR(150),
	city VARCHAR(150),
	postal_code VARCHAR(100),
	address VARCHAR(255)    
);

LOAD DATA LOCAL INFILE '/Users/esrakesken/barcelona_activa/american_users.csv' 
INTO TABLE american_users
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS; 


CREATE TABLE IF NOT EXISTS users (
	id INT PRIMARY KEY AUTO_INCREMENT,
	source_id INT NOT NULL,
	region ENUM('american','european') NOT NULL,
	name VARCHAR(100),
	surname VARCHAR(100),
	phone VARCHAR(150),
	email VARCHAR(150),
	birth_date VARCHAR(100),
	country VARCHAR(150),
	city VARCHAR(150),
	postal_code VARCHAR(100),
	address VARCHAR(255)    
);

INSERT INTO users (source_id, region, name, surname, phone, email, birth_date, country, city, postal_code, address)
SELECT id, 'american', name, surname, phone, email, birth_date, country, city, postal_code, address FROM american_users
UNION
SELECT id, 'european', name, surname, phone, email, birth_date, country, city, postal_code, address FROM european_users; 


DROP TABLE american_users;
DROP TABLE european_users;


CREATE TABLE IF NOT EXISTS transactions (
    id VARCHAR(255) PRIMARY KEY,
    card_id VARCHAR(20),
    business_id VARCHAR(100),
    timestamp DATETIME,
    amount DECIMAL(10,2),
    declined TINYINT,
    product_ids VARCHAR(100),
    user_id INT,
    latitude DOUBLE,
    longtitude DOUBLE,
   
	FOREIGN KEY (card_id) REFERENCES credit_cards(id),
    FOREIGN KEY (business_id) REFERENCES companies(company_id),
    FOREIGN KEY (user_id) REFERENCES users(id)
); 

LOAD DATA LOCAL INFILE '/Users/esrakesken/barcelona_activa/transactions.csv' 
INTO TABLE transactions
FIELDS TERMINATED BY ';' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;    



#Exercise 1:Perform a subquery that shows all users with more than 80 transactions, using at least 2 tables.
SELECT id,
	   name,
       surname
FROM users 
WHERE id IN (
      SELECT user_id
      FROM transactions 
      GROUP BY user_id
      HAVING COUNT(id) > 80 
);
      


#Exercise 2: Show the average amount per IBAN of credit cards in the company Donec Ltd, using at least 2 tables.
SELECT c.company_name,
       cc.iban,
       AVG(t.amount) AS avg_amount
FROM transactions t
JOIN credit_cards cc ON t.card_id = cc.id
JOIN companies c ON t.business_id = c.company_id
WHERE c.company_name = 'Donec Ltd' 
GROUP BY cc.iban
ORDER BY avg_amount DESC;


#LEVEL 2
#Create a new table that reflects the status of credit cards based on whether the last three transactions were declined
CREATE TABLE IF NOT EXISTS card_status (
     id VARCHAR(20) PRIMARY KEY,
     status VARCHAR(20) 
);

INSERT INTO card_status (id, status)
SELECT card_id,
       CASE 
           WHEN SUM(declined) = 3 THEN 'declined_last_3'
           ELSE 'active'
       END AS status
FROM (
    SELECT card_id,
           declined,
           ROW_NUMBER() OVER (PARTITION BY card_id ORDER BY timestamp DESC) AS rn
    FROM transactions
) AS ranked
WHERE rn <= 3
GROUP BY card_id;


#Exercise 1:How many cards are active?
SELECT COUNT(*) AS active_card_count
FROM card_status
WHERE status = 'active';

#Set up a relationship between the credit_cards and the table card_status:
ALTER TABLE credit_cards
ADD FOREIGN KEY(id) REFERENCES card_status(id);


#LEVEL 3
#Create a table with which we can join the data from the new products.csv file with the created database, taking into account that from the transaction, you have product_ids. Generate the following query:
CREATE TABLE transaction_products (
     transaction_id VARCHAR(255),
     product_id INT,
     PRIMARY KEY (transaction_id,product_id)
);



INSERT INTO transaction_products (transaction_id, product_id)
WITH RECURSIVE split_products AS (
     SELECT
        id AS transaction_id,
        TRIM(SUBSTRING_INDEX(product_ids, ',', 1)) AS product_id,
        SUBSTRING(product_ids, LENGTH(SUBSTRING_INDEX(product_ids, ',', 1)) + 2) AS rest
	FROM transactions
    WHERE product_ids IS NOT NULL AND product_ids <> ''
    
    UNION ALL
    
    SELECT
		transaction_id,
		TRIM(SUBSTRING_INDEX(rest, ',', 1)) AS product_id,
        SUBSTRING(rest, LENGTH(SUBSTRING_INDEX(rest, ',', 1)) + 2) AS rest
    FROM split_products
    WHERE rest IS NOT NULL AND rest <> ''
)
SELECT 
       transaction_id,
	   CAST(product_id AS UNSIGNED) AS product_id
FROM split_products;


AlTER TABLE transaction_products
ADD FOREIGN KEY (transaction_id) REFERENCES transactions(id),
ADD FOREIGN KEY (product_id) REFERENCES products(id);

#Exercise 1: We need to know the number of times each product has been sold.
SELECT 
       tp.product_id,
       p.product_name,
	   COUNT(*) AS total_sold
FROM transaction_products tp
JOIN products p ON tp.product_id = p.id
GROUP BY tp.product_id, p.product_name
ORDER BY total_sold;
