{#
  Standardize text columns with trimming and case transformation.

  Args:
    column: The column to standardize
    case: 'upper', 'lower', 'title', or null (trim only). Default: null

  Examples:
    SELECT {{ standardize_text('full_name', 'upper') }} as full_name
    SELECT {{ standardize_text('department') }} as department
#}

{% macro standardize_text(column, case=none) %}
  {% if case == 'upper' %}
    upper(trim({{ column }}))
  {% elif case == 'lower' %}
    lower(trim({{ column }}))
  {% elif case == 'title' %}
    initcap(trim({{ column }}))
  {% else %}
    trim({{ column }})
  {% endif %}
{% endmacro %}
