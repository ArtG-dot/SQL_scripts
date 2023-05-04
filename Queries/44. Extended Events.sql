create event session session_name
on server
add event sqlos.wait_info
(
	where sqlserver.session_id = 53
)
add target package0.event_file
(
	set filename = 'c:\...\file.xel'
);


alter event session session_name
on server
state = start;

drop event session session_name
on server