--Report 1 - Advances paid to each author

SELECT  a.Au_name AS Author_Name , b.title AS book_Name, p.ytd_sales AS Sale_to_Date,  p.advanceperauthor AS Advance_Paid
FROM books_title b INNER JOIN payment_facts p ON b.titlekey = p.titlekey 
INNER JOIN Author_titleau a ON a.Authorkey = p.Authorkey
ORDER BY advanceperauthor DESC

--Report 2 - Payments to each author, ordered by book name

SELECT  a.Au_name AS Author_Name , b.title AS book_Name, p.ytd_sales AS Sale_to_Date, p.royaltyper AS '%_royalty', 
		p.roypay_ytdsales AS Amount_of_Royalty_earned, p.advanceperauthor, p.totalPay AS Total_earning
FROM books_title b INNER JOIN payment_facts p ON b.titlekey = p.titlekey 
INNER JOIN Author_titleau a ON a.Authorkey = p.Authorkey
ORDER BY p.roypay_ytdsales DESC

--Report 3 - Total earning by each Author

SELECT  a.Au_name, SUM(p.advanceperauthor) AS total_advance_earned, SUM(p.roypay_ytdsales) AS royalaty_earned, SUM(p.totalPay) AS Total_earnings
FROM Author_titleau a INNER JOIN payment_facts p ON a.Authorkey = p.Authorkey 
GROUP BY a.Au_name
ORDER BY Total_earnings DESC