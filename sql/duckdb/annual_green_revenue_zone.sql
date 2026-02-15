SELECT pickup_zone, sum(revenue_monthly_total_amount) as revenue_year_total_amount 
FROM prod.fct_monthly_zone_revenue 
WHERE service_type='Green'
AND year(revenue_month) = 2020 
GROUP BY 1
ORDER BY revenue_year_total_amount DESC