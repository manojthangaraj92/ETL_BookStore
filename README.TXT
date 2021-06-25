


We look to create a Data warehouse to produce reports for payments to authors. There are 2 main types of payments: Advance, and Royalties 
as a percentage of sales. We extracted the information from the publisher’s databases via Visual studios, using Kimball star schema. In 
the relational database, there are 4 tables that include this information. As Authors may write/contribute to more than one book, have 
identified the atomic grain as individual payments to authors. This allows us to produce reports from this level of detail or in larger 
forms. These reports may be reproduced over different time periods to identify high earners/ best performing authors/books.