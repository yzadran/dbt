{% macro synapse__create_external_schema(source_node) %}
    {# https://learn.microsoft.com/en-us/sql/t-sql/statements/create-schema-transact-sql?view=sql-server-ver16 #}

    {% set ddl %}
        IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = '{{ source_node.schema }}')
        BEGIN
        EXEC('CREATE SCHEMA [{{ source_node.schema }}]')
        END 
    {% endset %}

    {{return(ddl)}}

{% endmacro %}

{% macro synapse__create_external_table(source_node) %}

    {%- set columns = source_node.columns.values() -%}
    {%- set external = source_node.external -%}

    {% if external.ansi_nulls is true -%} SET ANSI_NULLS ON; {%- endif %}
    {% if external.quoted_identifier is true -%} SET QUOTED_IDENTIFIER ON; {%- endif %}

    create external table {{source(source_node.source_name, source_node.name)}} (
        {% for column in columns %}
            {# TODO set nullity based on schema tests?? #}
            {%- set nullity = 'NOT NULL' if 'not_null' in columns.tests else 'NULL'-%}
            {{adapter.quote(column.name)}} {{column.data_type}} {{nullity}}
            {{- ',' if not loop.last -}}
        {% endfor %}
    )
    WITH (
        {# remove keys that are None (i.e. not defined for a given source) #}
        {%- for key, value in external.items() if value is not none and key not in ['ansi_nulls', 'quoted_identifier'] -%}
            {{key}} = 
                {%- if key in ["location", "schema_name", "object_name"] -%}
                    '{{value}}'
                {% elif key in ["data_source","file_format"] -%}
                    [{{value}}]
                {% else -%}
                    {{value}}
                {%- endif -%}
            {{- ',' if not loop.last -}}
            {%- endfor -%}
    )
{% endmacro %}

{% macro synapse__get_external_build_plan(source_node) %}

    {% set build_plan = [] %}

    {% set old_relation = adapter.get_relation(
        database = source_node.database,
        schema = source_node.schema,
        identifier = source_node.identifier
    ) %}

    {% set create_or_replace = (old_relation is none or var('ext_full_refresh', false)) %}

    {% if create_or_replace %}
        {% set build_plan = build_plan + [ 
            dbt_external_tables.create_external_schema(source_node),
            dbt_external_tables.dropif(source_node), 
            dbt_external_tables.create_external_table(source_node)
        ] %}
    {% else %}
        {% set build_plan = build_plan + dbt_external_tables.refresh_external_table(source_node) %}
    {% endif %}
    {% do return(build_plan) %}

{% endmacro %}

{% macro synapse__dropif(node) %}
    
    {% set ddl %}
      if object_id ('{{source(node.source_name, node.name)}}') is not null
        begin
        drop external table {{source(node.source_name, node.name)}}
        end
    {% endset %}
    
    {{return(ddl)}}

{% endmacro %}