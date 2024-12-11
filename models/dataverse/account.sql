{{ 
    config(
        materialized='table',
        schema='crm'
    ) 
}}

SELECT * FRO {{ source('dataverse', 'account') }}