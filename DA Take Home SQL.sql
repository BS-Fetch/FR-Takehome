--In order to complete this take home assessment I was provided with CSV files that I uploaded to GCP (specifically, into Google BigQuery). 
--I then wrote out all of the below queries to check the data and answer the questions
--since this is in GBQ, it is using Google SQL, which is quite similar to PostGreSQL

--first things first, look at the data and try to understand the fields available

select * 
from `wide-memento-453516-g0.my_project.tbl_products` limit 100;
--makes sense, but seems like nulls in manufacturer and brand, lets check

select
  count(*) as totalproducts,
  sum(case when brand is null then 1 else 0 end)/count(*) as null_brand_percent,
  sum(case when manufacturer is null then 1 else 0 end)/count(*) as null_manufacturer_percent,
from `wide-memento-453516-g0.my_project.tbl_products` limit 100;
-- ~27% of products have null manufacturer/brand, seems like a data quality issue

select *
from `wide-memento-453516-g0.my_project.tbl_users` limit 100;
--seems like lots of nulls, but could make sense if a user hasn't submitted personal info to us yet

select date(birth_date), count(*)
from `wide-memento-453516-g0.my_project.tbl_users` 
group by 1 order by 2 desc;
-- many null records

select * from `wide-memento-453516-g0.my_project.tbl_users` where date(birth_date) > '2020-01-01' or date(birth_date) < '1925-01-01'
-- about 75 records from peole that are less than 5 years old or more than 100 years old, seems unlikely and probably a data quality error

select * 
from `wide-memento-453516-g0.my_project.tbl_transactions` limit 100;
--mostly makes sense, very odd that final_quantity is a string and has 0s as "zero" but other numbers in numeric form

select 
  sum(case when barcode is null then 1 else 0 end)/count(*) as percent_null_barcodes
from `wide-memento-453516-g0.my_project.tbl_transactions`;
-- 11% of transactions have a null barcode, seems like an issue because they we can't join back to the brand

select 
  sum(case when user_id is null then 1 else 0 end)/count(*) as percent_null_barcodes
from `wide-memento-453516-g0.my_project.tbl_transactions`;
-- no null user ids

select
  count(*)
from `wide-memento-453516-g0.my_project.tbl_transactions` a
left outer join `wide-memento-453516-g0.my_project.tbl_users` b on a.USER_ID = b.ID
where b.id is null;
-- 50k records for user ids that are in transactions but don't exist within the users table, definitely a problem because these records could drop if you inner joined and don't realize

select
  RECEIPT_ID, count(*)
from `wide-memento-453516-g0.my_project.tbl_transactions`
group by 1
having count(*) > 1
order by 2 desc;
--duplicates in transactions

--bedac253-2256-461b-96af-267748e6cecf, 12 records
select * from `wide-memento-453516-g0.my_project.tbl_transactions` where receipt_id = 'bedac253-2256-461b-96af-267748e6cecf'
--strange results, seems mostly like true duplicates but there is some difference in the final quantity and final sale columns for some records

--open questions about fields in this table: 
-- is purchase date when they bought the product and scan date when they tried to upload to fetch for rewards?
-- how could final sale be populated in trasnsactions if final quantity is zero?

--QUESTIONS

-- top 5 brands by receipts scanned among users 21 and over?

select
  c.brand,
  count(distinct a.receipt_id) as receipts_scanned
from `wide-memento-453516-g0.my_project.tbl_transactions` a 
left outer join `wide-memento-453516-g0.my_project.tbl_users` b on a.USER_ID = b.ID
left outer join `wide-memento-453516-g0.my_project.tbl_products` c on a.BARCODE = c.BARCODE
where date(b.BIRTH_DATE) < (current_date - (21*365)) --birthday is before 21 years before today
  and c.BRAND is not null --top brand is null because of missing data (which I purposely kept per the left joins)
group by 1
order by 2 desc
limit 5; --just get the top 5

--What are the top 5 brands by sales among users that have had their account for at least six months?

--you could interpret sales as revenue or products sold
--you could interpret at least 6 months as 6 months from today, or 6 months before the purchase date
--I am choosing revenue and 6 months before purchase date for these open Qs
select
  c.brand,
  sum(cast((case when a.FINAL_SALE = ' ' then null else a.FINAL_SALE end) as numeric)) as sales_revenue
from `wide-memento-453516-g0.my_project.tbl_transactions` a 
left outer join `wide-memento-453516-g0.my_project.tbl_users` b on a.USER_ID = b.ID
left outer join `wide-memento-453516-g0.my_project.tbl_products` c on a.BARCODE = c.BARCODE
where date_diff(date(a.PURCHASE_DATE), date(b.CREATED_DATE), month) > 6
  and c.BRAND is not null --top brand is null because of missing data (which I purposely kept per the left joins)
group by 1
order by 2 desc
limit 5; --just get the top 5


--What is the percentage of sales in the Health & Wellness category by generation?

--how do we define generation? using made up date ranges. n/a is the largest share by far because we don't have most folks birthday

with pre as (
  select
    sum(cast((case when a.FINAL_SALE = ' ' then null else a.FINAL_SALE end) as numeric)) as sales_revenue
  from `wide-memento-453516-g0.my_project.tbl_transactions` a 
  left outer join `wide-memento-453516-g0.my_project.tbl_products` c on a.BARCODE = c.BARCODE
  where c.CATEGORY_1 = 'Health & Wellness'
)
select
  case  
    when b.BIRTH_DATE < '1965-01-01' then 'Boomer'
    when b.BIRTH_DATE between '1965-01-01' and '1980-01-01' then 'GenX'
    when b.BIRTH_DATE between '1980-01-02' and '1995-01-01' then 'Millenials'
    when b.BIRTH_DATE > '1995-01-01' then 'GenZ'
    else 'n/a'
  end as Generation,
  sum(cast((case when a.FINAL_SALE = ' ' then null else a.FINAL_SALE end) as numeric))/d.sales_revenue as sales_revenue_percent
from `wide-memento-453516-g0.my_project.tbl_transactions` a 
left outer join `wide-memento-453516-g0.my_project.tbl_users` b on a.USER_ID = b.ID
left outer join `wide-memento-453516-g0.my_project.tbl_products` c on a.BARCODE = c.BARCODE
cross join pre d --adding this in so I can divide by total
where c.CATEGORY_1 = 'Health & Wellness'
group by 1,d.sales_revenue
order by 2 desc
;


-- who are fetch's power users?

--below is the top 10 users, the top 5 from receipts scanned and top 5 from sales revenue. in this case those happens to be 10 different people but this query is written in such a way that if they were the same it would only count each of those people once. I am assuming that the scans in the transaction table were approved and there is no time limit to scan purchases
with pre as (
(select 
  user_id,
  count(distinct a.receipt_id) as scans
from `wide-memento-453516-g0.my_project.tbl_transactions` a
where FINAL_QUANTITY <> 'zero'
group by 1
order by 2 desc
limit 5)
union distinct
(select 
  user_id,
  sum(cast((case when a.FINAL_SALE = ' ' then null else a.FINAL_SALE end) as numeric)) as rev
from `wide-memento-453516-g0.my_project.tbl_transactions` a
where FINAL_QUANTITY <> 'zero'
group by 1
order by 2 desc
limit 5)
)
select 
  user_id 
from pre



--Which is the leading brand in the Dips & Salsa category?

select
  c.BRAND,
  sum(cast((case when a.FINAL_SALE = ' ' then null else a.FINAL_SALE end) as numeric)) as sales_revenue
from `wide-memento-453516-g0.my_project.tbl_transactions` a 
left outer join `wide-memento-453516-g0.my_project.tbl_products` c on a.BARCODE = c.BARCODE
where c.CATEGORY_2 = 'Dips & Salsa'
group by 1
order by 2 desc
limit 1
;
--this assumes no date constraints and assumes final_sale is the revenue generated from each transaction


--At what percent has Fetch grown year over year?

select
  extract(year from a.PURCHASE_DATE),
  sum(cast((case when a.FINAL_SALE = ' ' then null else a.FINAL_SALE end) as numeric)) as sales_revenue
from `wide-memento-453516-g0.my_project.tbl_transactions` a 
group by 1 
order by 1 desc

-- seeing only 2024 data so not possible to calculate year over year growth, but could be done with a self join

