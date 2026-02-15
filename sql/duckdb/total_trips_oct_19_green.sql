SELECT revenue_month, sum(total_monthly_trips)
FROM prod.fct_monthly_zone_revenue 
WHERE service_type='Green'
    AND year(revenue_month) = 2019
    AND month(revenue_month) = 10
GROUP BY 1