-- Afficher les 10 premières lignes du customers

SELECT * 
FROM customers
LIMIT 10;

-- Afficher les 5 premières lignes du products

SELECT *
FROM products
LIMIT 5;

-- Compter des lignes du products

SELECT COUNT(*)
FROM products;

-- Écrivez une requête pour afficher le tableau suivant :
-- Sélectionnez chaque nom de table sous forme de chaîne.
-- Sélectionnez le nombre d'attributs sous forme d'entier (comptez le nombre d'attributs par table).
-- Sélectionnez le nombre de lignes à l'aide de la fonction COUNT(*).
-- Utilisez l'opérateur composé UNION ALL pour lier ces lignes ensemble.

SELECT 'Customers' AS table_name, 13 AS number_of_attributes, COUNT(*) AS number_of_rows
FROM customers
UNION ALL
SELECT 'Products' AS table_name, 9 AS number_of_attributes, COUNT(*) AS number_of_rows
FROM products
UNION ALL
SELECT 'Productlines' AS table_name, 4 AS number_of_attributes, COUNT(*) AS number_of_rows
FROM productlines
UNION ALL
SELECT 'Orders' AS table_name, 7 AS number_of_attributes, COUNT(*) AS number_of_rows
FROM orders
UNION ALL
SELECT 'OrderDetails' AS table_name, 5 AS number_of_attributes, COUNT(*) AS number_of_rows
FROM orderdetails
UNION ALL
SELECT 'Payments' AS table_name, 4 AS number_of_attributes, COUNT(*) AS number_of_rows
FROM payments
UNION ALL
SELECT 'Employees' AS table_name, 8 AS number_of_attributes, COUNT(*) AS number_of_rows
FROM employees
UNION ALL
SELECT 'Offices' AS table_name, 9 AS number_of_attributes, COUNT(*) AS number_of_rows
FROM offices
;

-- Question 1:
-- Quels produits devrions-nous commander plus ou moins? Cette question fait référence aux rapports d'inventaire, y compris les faibles stocks ' low stock' et les performances des produits'product performance'.
-- Cela permettra d'optimiser l'offre et l'expérience utilisateur en évitant les ruptures de stock des produits les plus vendus.

SELECT *
FROM products;
SELECT * 
FROM orderdetails;

-- Écriver une requête pour calculer le stock faible pour chaque produit à l'aide d'une sous-requête corrélée.

SELECT productCode, ROUND(SUM(quantityOrdered)*1.0 /
       (SELECT quantityInStock
	    FROM products pr
		WHERE pr.productCode = od.productCode),2) AS low_stock
FROM orderdetails od
GROUP BY productCode
ORDER BY low_stock
LIMIT 20
;	

-- Écrivez une requête pour calculer les performances du produit pour chaque produit.

SELECT productCode, SUM(quantityOrdered * priceEach) AS product_perf
FROM orderdetails
GROUP BY productCode
ORDER BY product_perf DESC
LIMIT 20
;

-- Ecrivez une requête pour combiner les requêtes de faible stock et de performance du produit.

 WITH
  perf AS (
    SELECT productCode,
           SUM(quantityOrdered) * 1.0 AS quantityOrdr,	
           SUM(quantityOrdered * priceEach) AS prod_perf
      FROM orderdetails
     GROUP BY productCode
  ),
  lostk AS (
    SELECT pr.productCode, 
	       pr.productName, 
		   pr.productLine,
           ROUND(SUM(perf.quantityOrdr * 1.0) / pr.quantityInstock, 2) AS low_stock
      FROM products pr
	  JOIN perf
	    ON pr.productCode = perf.productCode
     GROUP BY pr.productCode
	 ORDER BY low_stock
	 LIMIT 15
  )
    SELECT lostk.productName, 
	       lostk.productLine
	  FROM lostk
	  JOIN perf
	    ON lostk.productCode = perf.productCode
	 ORDER BY perf.prod_perf DESC;
-- 	=> Les voitures classiques sont la priorité pour le réapprovisionnement. Ils se vendent fréquemment et ce sont les produits les plus performants. 
	 
	 
-- Question 2 : Comment aligner les stratégies de marketing et de communication sur le comportement des clients ?
-- This involves categorizing customers: finding the VIP (very important person) customers and those who are less engaged.
-- Les clients VIP rapportent le plus de profit au magasin.
-- Les clients moins engagés génèrent moins de bénéfices.
-- => Nous pourrions organiser des événements pour fidéliser les VIP et lancer une campagne pour les moins engagés.

-- Écrivez une requête pour afficher les clients et les bénéfices générés par eux en joignant les tables de produits, de détails de commande(s)

SELECT o.customerNumber, SUM(quantityOrdered * (priceEach - buyPrice)) AS profit
FROM products pr
JOIN orderdetails od ON od.productCode = pr.productCode
JOIN orders o ON o.orderNumber = od.orderNumber
GROUP BY o.customerNumber
ORDER BY profit DESC;

-- Écrivez une requête pour afficher le top 5 clients et les bénéfices générés par eux en utilisant CTE(common Table Expression)

WITH 
profit_tab AS (SELECT o.customerNumber, SUM(quantityOrdered * (priceEach - buyPrice)) AS profit
               FROM products pr
			   JOIN orderdetails od ON od.productCode = pr.productCode
			   JOIN orders o ON o.orderNumber = od.orderNumber
			   GROUP BY o.customerNumber
			   )
SELECT contactLastName, contactFirstName, city, country, protab.profit
FROM customers cus	   
JOIN profit_tab protab ON protab.customerNumber = cus.customerNumber
ORDER BY profit DESC
LIMIT 5;

-- Question 3: Combien pouvons-nous dépenser pour acquérir de nouveaux clients ?
-- On va trouver le nombre de nouveaux clients qui arrivent chaque mois. De cette façon, nous pouvons vérifier si cela vaut la peine de dépenser de l'argent pour acquérir de nouveaux clients.

WITH 
    payment_tab AS
	               (SELECT *,CAST(SUBSTR(paymentDate,1,4) AS INTEGER)*100 +
	                         CAST(SUBSTR(paymentDate,6,7) AS INTEGER) AS year_month
				     FROM payments p),
	customers_month_tab AS 
	               (SELECT p1.year_month, COUNT(*) AS nb_customers,
                           SUM(p1.amount) AS total   
					FROM payment_tab p1
					GROUP BY p1.year_month
					),
    new_customers_month_tab AS
                   (SELECT p1.year_month, COUNT(*) AS nb_new_customers,
				           SUM(p1.amount) AS new_customers_total,
						   (SELECT nb_customers
						    FROM customers_month_tab c
						    WHERE c.year_month = p1.year_month) AS nb_customers,	
							(SELECT total
							 FROM customers_month_tab c
							 WHERE c.year_month = p1.year_month) AS total
				     FROM payment_tab p1	
			         WHERE p1.customerNumber NOT IN (SELECT customerNumber
				                                     FROM payment_tab p2
												     WHERE p2.year_month < p1.year_month)
					 GROUP BY p1.year_month)
SELECT year_month, ROUND(nb_new_customers *100 / nb_customers, 1) AS nb_new_customers_prop,
       ROUND(new_customers_total *100/ total, 1) AS new_customers_prop
FROM new_customers_month_tab;	   

-- => Le nombre de clients diminue depuis 2003, et en 2004, nous avions les valeurs les plus basses. L'année 2005, qui est également présente dans la base de données, n'est pas présente dans le tableau ci-dessus, cela signifie que le magasin n'a pas eu de nouveaux clients depuis septembre 2004. Cela signifie qu'il est logique de dépenser de l'argent pour acquérir de nouveaux clients.

-- Combien pouvons-nous dépenser pour acquérir de nouveaux clients? 
-- La valeur à vie nous indique le profit qu'un client moyen génère au cours de sa vie avec notre magasin. Nous pouvons l'utiliser pour prédire nos bénéfices futurs.
WITH 
profit_tab AS (SELECT o.customerNumber, SUM(quantityOrdered * (priceEach - buyPrice)) AS profit
               FROM products pr
			   JOIN orderdetails od ON od.productCode = pr.productCode
			   JOIN orders o ON o.orderNumber = od.orderNumber
			   GROUP BY o.customerNumber
			   )
SELECT AVG(protab.profit) AS life_time_value
FROM profit_tab protab;			   

-- => La valeur moyenne de la durée de vie des clients de notre magasin est environ de 39 040 $. Cela signifie que pour chaque nouveau client, nous réalisons un bénéfice de 39 040 dollars.
-- Nous pouvons l'utiliser pour prédire combien nous pouvons dépenser pour l'acquisition de nouveaux clients, en même temps maintenir ou augmenter nos niveaux de profit.