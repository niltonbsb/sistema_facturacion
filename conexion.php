<?php 
	
	$host = 'localhost';
	$user = 'root';
	$password = '';
	$db = 'sistema_facturacion';

	$conection = @mysqli_connect($host,$user,$password,$db);
	if(!$conection){
		echo "Error en la conexión";
	}
	mysqli_set_charset($conection,"utf8mb4");

?>