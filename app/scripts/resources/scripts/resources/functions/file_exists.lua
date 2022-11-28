<<<<<<< HEAD

--check if a file exists
	function file_exists(name)
		local f = io.open(name, "r")
		if not f then return end
		f:close()
		return name
=======

--check if a file exists
	function file_exists(name)
		local f = io.open(name, "r")
		if not f then return end
		f:close()
		return name
>>>>>>> 5.0.1
	end