ALTER TABLE
  finance.category_type
ADD
  CONSTRAINT category_type_pkey PRIMARY KEY (id);


ALTER TABLE finance.categories
ADD CONSTRAINT fk_categories_type FOREIGN KEY (fk_category_type_id)
REFERENCES finance.category_type (id);

