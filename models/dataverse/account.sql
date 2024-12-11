{{ 
    config(
        materialized='table',
        schema='crm'
    ) 
}}

SELECT * FROM {{ source('dataverse', 'account') }}