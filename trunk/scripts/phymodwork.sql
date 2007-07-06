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


-- This also returns the root node for
-- the selected parent node
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

-- This is the select query which will
-- be used below
SELECT pt.node_id AS del_node_id 
FROM node_path p, edge e, node pt, node ch 
WHERE e.child_node_id = p.child_node_id
AND pt.node_id = e.parent_node_id
AND ch.node_id = e.child_node_id
AND p.parent_node_id = '25';



-- A simple query
--SELECT * FROM node_path
--WHERE parent_node_id = '10';

SELECT * FROM node_path WHERE parent_node_id = '10';

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

--Attributes
