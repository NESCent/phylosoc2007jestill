--- Leaf nodes from all trees ---
SELECT * FROM node
WHERE(right_idx-left_idx)=1;

--- Leaf nodes from a specific tree ---
SELECT * FROM node
WHERE(right_idx-left_idx)=1 
AND tree_id = '1';
