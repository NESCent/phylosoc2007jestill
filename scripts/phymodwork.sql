-------------------------------------------------------------+
--
-- WORKING SQL CODE FOR THE PhyMod PROGRAM
--
-------------------------------------------------------------+
-- 07/06/2007
-- JCE
--


-- The following from H. Lapp
-- works to select information about a tree
-- given a parent node
-- This makes use of the parent node information
-- from the node_path table
--SELECT e.edge_id, 
--       pt.node_id AS parent_node_id, 
--       pt.label AS parent_label, 
--       ch.node_id AS child_node_id, 
--       ch.label AS child_label
--FROM node_path p, 
--     edge e, 
--     node pt, 
--     node ch 
--WHERE 
--    e.child_node_id = p.child_node_id
--AND pt.node_id = e.parent_node_id
--AND ch.node_id = e.child_node_id
--AND p.parent_node_id = '25'


-- The above can be modified for delete queries
-- Using a nested SQL query





-------------------------------------------------------------+
-- THE FOLLOWING CODE IS RELATED TO NEEDS OF THE             |
-- CUT AND COPY QUERIES                                      |
-------------------------------------------------------------+

system echo '==============================';
system echo ' BASE SELECT QUERY FOR NODES';
system echo '==============================';

-- This is the select query which will
-- be used below as part of a nested query
SELECT pt.node_id AS del_node_id 
FROM node_path p, edge e, node pt, node ch 
WHERE e.child_node_id = p.child_node_id
AND pt.node_id = e.parent_node_id
AND ch.node_id = e.child_node_id
AND p.parent_node_id = '25';

-------------------------------+
-- TABLE: node_path           
-------------------------------+
system echo '==============================';
system echo ' TABLE: node_path';
system echo '==============================';
-- THESE ARE RECORDS FROM node_path WHERE 
-- the children of the parent_node are
-- parents
SELECT * FROM node_path 
WHERE parent_node_id IN
(
 SELECT pt.node_id 
 FROM node_path p, edge e, node pt, node ch 
 WHERE e.child_node_id = p.child_node_id
 AND pt.node_id = e.parent_node_id
 AND ch.node_id = e.child_node_id
 AND p.parent_node_id = '25'
);

SELECT COUNT(*) FROM node_path 
WHERE parent_node_id IN
(
 SELECT pt.node_id 
 FROM node_path p, edge e, node pt, node ch 
 WHERE e.child_node_id = p.child_node_id
 AND pt.node_id = e.parent_node_id
 AND ch.node_id = e.child_node_id
 AND p.parent_node_id = '25'
);

-- These are records from node_path WHERE
-- the children of the parent_node are
-- parents
SELECT * FROM node_path 
WHERE child_node_id IN
(
 SELECT pt.node_id 
 FROM node_path p, edge e, node pt, node ch 
 WHERE e.child_node_id = p.child_node_id
 AND pt.node_id = e.parent_node_id
 AND ch.node_id = e.child_node_id
 AND p.parent_node_id = '25'
);

SELECT COUNT(*) FROM node_path 
WHERE child_node_id IN
(
 SELECT pt.node_id 
 FROM node_path p, edge e, node pt, node ch 
 WHERE e.child_node_id = p.child_node_id
 AND pt.node_id = e.parent_node_id
 AND ch.node_id = e.child_node_id
 AND p.parent_node_id = '25'
);

-------------------------------+
-- TABLE: node_attribute_value |
-------------------------------+
system echo '==============================';
system echo ' TABLE: node_attribute_value';
system echo '==============================';
SELECT * FROM node_attribute_value 
WHERE node_id IN
(
 SELECT pt.node_id 
 FROM node_path p, edge e, node pt, node ch 
 WHERE e.child_node_id = p.child_node_id
 AND pt.node_id = e.parent_node_id
 AND ch.node_id = e.child_node_id
 AND p.parent_node_id = '25'
);

SELECT COUNT(*) FROM node_attribute_value 
WHERE node_id IN
(
 SELECT pt.node_id 
 FROM node_path p, edge e, node pt, node ch 
 WHERE e.child_node_id = p.child_node_id
 AND pt.node_id = e.parent_node_id
 AND ch.node_id = e.child_node_id
 AND p.parent_node_id = '25'
);


-------------------------------+
-- TABLE: node                 |
-------------------------------+
system echo '==============================';
system echo ' TABLE: node';
system echo '==============================';
SELECT * FROM node 
WHERE node_id IN
(
 SELECT pt.node_id 
 FROM node_path p, edge e, node pt, node ch 
 WHERE e.child_node_id = p.child_node_id
 AND pt.node_id = e.parent_node_id
 AND ch.node_id = e.child_node_id
 AND p.parent_node_id = '25'
);


SELECT COUNT(*) FROM node 
WHERE node_id IN
(
 SELECT pt.node_id 
 FROM node_path p, edge e, node pt, node ch 
 WHERE e.child_node_id = p.child_node_id
 AND pt.node_id = e.parent_node_id
 AND ch.node_id = e.child_node_id
 AND p.parent_node_id = '25'
);

-------------------------------+
-- TABLE: edge_attribute_value |
-------------------------------+
--SELECT * FROM node_attribute_value 
--WHERE node_id IN
--(
-- SELECT pt.node_id 
-- FROM node_path p, edge e, node pt, node ch 
-- WHERE e.child_node_id = p.child_node_id
-- AND pt.node_id = e.parent_node_id
-- AND ch.node_id = e.child_node_id
-- AND p.parent_node_id = '25'
--);


-------------------------------+
-- TABLE: edge
-------------------------------+
system echo '==============================';
system echo ' TABLE: edge';
system echo '==============================';
SELECT e.edge_id 
FROM node_path p, 
     edge e, 
     node pt, 
     node ch 
WHERE 
    e.child_node_id = p.child_node_id
AND pt.node_id = e.parent_node_id
AND ch.node_id = e.child_node_id
AND p.parent_node_id = '25';


SELECT * from edge 
WHERE edge_id IN
(
 SELECT e.edge_id 
 FROM node_path p, edge e, node pt, node ch 
 WHERE e.child_node_id = p.child_node_id
 AND pt.node_id = e.parent_node_id
 AND ch.node_id = e.child_node_id
 AND p.parent_node_id = '25'
);




-------------------------------+
-- TABLE: edge_attribute_value |
-------------------------------+
system echo '==================================';
system echo ' TABLE: edge_attribute_value info';
system echo '==================================';
SELECT * FROM edge_attribute_value
WHERE edge_id IN 
(
 SELECT e.edge_id 
 FROM node_path p, edge e, node pt, node ch 
 WHERE e.child_node_id = p.child_node_id
 AND pt.node_id = e.parent_node_id
 AND ch.node_id = e.child_node_id
 AND p.parent_node_id = '25'
);


system echo '==================================';
system echo ' TREE DATA';
system echo '==================================';
SELECT tree.name FROM tree
RIGHT JOIN node
ON node.tree_id = tree.tree_id
WHERE node.node_id = '25';



system echo '==================================';
system echo ' DELETE ';
system echo '==================================';

DELETE FROM edge_attribute_value
WHERE edge_id IN 
(
 SELECT e.edge_id 
 FROM node_path p, edge e, node pt, node ch 
 WHERE e.child_node_id = p.child_node_id
 AND pt.node_id = e.parent_node_id
 AND ch.node_id = e.child_node_id
 AND p.parent_node_id = '25'
);


-- The following does not work
--DELETE FROM node_path
--WHERE parent_node_id IN
--(	
-- SELECT pt.node_id
-- FROM node_path p, edge e, node pt, node ch
-- WHERE e.child_node_id = p.child_node_id
-- AND pt.node_id = e.parent_node_id
-- AND ch.node_id = e.child_node_id
-- AND p.parent_node_id = '25'
--)

DELTE FROM edge_attribute_value".
	" WHERE edge_id IN".
	" (".
	"  SELECT e.edge_id".
	"  FROM node_path p, edge e, node pt, node ch".
	"  WHERE e.child_node_id = p.child_node_id".
	"  AND pt.node_id = e.parent_node_id".
	"  AND ch.node_id = e.child_node_id".
	"  AND p.parent_node_id = '$del_node_id'".