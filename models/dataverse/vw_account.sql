{{ 
    config(
        materialized='view'

    )
}}

SELECT * FROM {{ source('dataverse', 'account') }}
WHERE C8 ='World'