CREATE OR REPLACE VIEW finance.monthly_spending_two_months_ago_view AS
SELECT 
    c.name AS category_name,
    m.name AS month_name,
    y.year AS year,
    ms.amount AS amount
FROM 
    finance.monthly_spending ms
JOIN 
    finance.categories c ON ms.fk_category_id = c.id
JOIN 
    finance.month m ON ms.fk_month_id = m.id
JOIN 
    finance.years y ON ms.fk_year_id = y.id
WHERE 
    y.year = EXTRACT(YEAR FROM CURRENT_TIMESTAMP) 
    AND 
    m.cardinal = CASE 
                    WHEN EXTRACT(MONTH FROM CURRENT_TIMESTAMP) = 1 
                    THEN 11
	       	    WHEN EXTRACT(MONTH FROM CURRENT_TIMESTAMP) = 2
		    THEN 12	
                    ELSE EXTRACT(MONTH FROM CURRENT_TIMESTAMP) - 2 
                 END;

