<?php
	session_start();
	include "../../conexion.php";

	$busqueda	= '';
	$fecha_de 	= '';
	$fecha_a 	= '';
	$where 		= '';
	$whereCl 	= '';
	$whereUs 	= '';
	$wherePago 	= '';

	if(empty($_REQUEST['busqueda']) && empty($_REQUEST['fecha_de']) && empty($_REQUEST['fecha_a']))
	{
		header("location: index.php");
	}

	if(!empty($_REQUEST['busqueda'])){

		$busqueda = strtolower($_REQUEST['busqueda']);
		$where ="f.nofactura = '$busqueda' ";
		$buscar = 'busqueda='.$busqueda;

		//Buscar Por cliente
		$querySerchCliente = mysqli_query($conection,"SELECT idcliente
												FROM cliente
												WHERE (nit LIKE '%$busqueda%') AND estatus != 10
												ORDER BY nombre DESC ");
		$resultSearchCliente = mysqli_num_rows($querySerchCliente);
		if($resultSearchCliente > 0){
			while ($arrSerarchCliente = mysqli_fetch_assoc($querySerchCliente)){
				$idClienteSearch = $arrSerarchCliente['idcliente'];
				$whereCl .= ' OR f.codcliente LIKE '.$idClienteSearch. ' ';
			}
		}
		//Buscar Por vendedor
		$querySerchUsuario = mysqli_query($conection,"SELECT idusuario
												FROM usuario
												WHERE nombre LIKE '%$busqueda%' AND estatus != 10
												ORDER BY nombre DESC ");
		$resultSearchUsuario = mysqli_num_rows($querySerchUsuario);
		if($resultSearchUsuario > 0){
			while ($arrSerarchUsuario = mysqli_fetch_assoc($querySerchUsuario)){
				$idUsuarioSearch = $arrSerarchUsuario['idusuario'];
				$whereUs .= ' OR f.usuario LIKE '.$idUsuarioSearch. ' ';
			}
		}
		//Buscar Por Tipo de pago
		$queryPago = mysqli_query($conection,"SELECT id_tipopago
											FROM tipo_pago
											WHERE tipo_pago LIKE '%$busqueda%' AND estatus != 10
											ORDER BY tipo_pago DESC ");
		$resultPago = mysqli_num_rows($queryPago);
		if($resultPago > 0){
			while ($arrSerarchPago = mysqli_fetch_assoc($queryPago)){
				$idPago = $arrSerarchPago['id_tipopago'];
				$wherePago .= ' OR f.tipopago_id LIKE '.$idPago. ' ';
			}
		}
	}

	if(!empty($_REQUEST['fecha_de']) && !empty($_REQUEST['fecha_a'])){
		$fecha_de = $_REQUEST['fecha_de'];
		$fecha_a = $_REQUEST['fecha_a'];

		$buscar = '';
		//$search_proveedor = $_REQUEST['proveedor'];
		if($fecha_de > $fecha_a){
			header("location: index.php");
		}else if($fecha_de == $fecha_a){

			$where = "fecha LIKE '$fecha_de%'";
			$buscar = "fecha_de=$fecha_de&fecha_a=$fecha_a";
		}else{
			$f_de = $fecha_de.' 00:00:00';
			$f_a = $fecha_a.' 23:59:59';
			$where = "fecha BETWEEN '$f_de' AND '$f_a'";
			$buscar = "fecha_de=$fecha_de&fecha_a=$fecha_a";

		}
	}

	//Paginador
	$sql_registe = mysqli_query($conection,"SELECT COUNT(*) as total_registro FROM factura as f WHERE $where $whereCl $whereUs $wherePago ");
	$result_register = mysqli_fetch_assoc($sql_registe);
	$total_registro = $result_register['total_registro'];

	$por_pagina = 200;

	if(empty($_GET['pagina']))
	{
		$pagina = 1;
	}else{
		$pagina = $_GET['pagina'];
	}

	$desde = ($pagina-1) * $por_pagina;
	$total_paginas = ceil($total_registro / $por_pagina);
	$x=$_REQUEST['fecha_de'];
	$y = $_REQUEST['fecha_a'];
	
	$queryExport = "SELECT f.nofactura,f.factura_serie,DATE_FORMAT(f.fecha, '%d/%m/%Y') as fecha,f.totalfactura,f.codcliente,f.estatus,
											 u.nombre as vendedor,
											 cl.nit,
											 cl.nombre as cliente,
											 tp.tipo_pago,
											 s.prefijo,s.ceros
										FROM factura f
										INNER JOIN usuario u
										ON f.usuario = u.idusuario
										INNER JOIN cliente cl
										ON f.codcliente = cl.idcliente
										INNER JOIN tipo_pago tp
										ON f.tipopago_id = tp.id_tipopago
										INNER JOIN facturas s
										ON f.serieid = s.idserie
										WHERE  $where $whereCl $whereUs $wherePago and f.estatus != 10
									  	ORDER BY f.fecha DESC ";

	$query_venta = "SELECT *
										FROM detallefactura df, producto p, factura f, usuario u

										WHERE   f.usuario= u.idusuario AND df.codproducto = p.codproducto and df.nofactura=f.nofactura  and f.fecha  
												BETWEEN '$x' and '$y'
										
										
									  	";
	$query = mysqli_query($conection,$query_venta);
	$result = mysqli_num_rows($query);
	echo "$result";
 ?>

<!DOCTYPE html>
<html lang="en">
<head>
	<meta charset="UTF-8">
	<?php include "../includes/scripts.php"; ?>
	<title>Buscar venta</title>
</head>
<body>
	<?php include "../includes/header.php"; ?>
	<section id="container">

		<h1><i class="fas fa-user"></i> Lista de ventas</h1>
		<a href="nueva_venta.php" class="btn_new"><i class="fas fa-plus"></i></i> Nueva venta</a>
		<?php if( $result > 0  and ($_SESSION['rol'] == 1 or $_SESSION['rol'] == 2)){ ?>
		<form action="exportar.php" method="post" class="formExport" >
			<input type="hidden" name="exportFilter" id="exportFilter" value="<?php echo $queryExport; ?>">
			<button type="submit" class="bntExport">  <i class="fas fa-file-excel"></i> Exportar Filtro</button>
		</form>
		<?php } ?>
		
		<div>
			<h5>Buscar por Fecha</h5>
			<form action="busqueda_reporte_venta.php" method="get" class="form_search_date">
				<label>De: </label>
				<input type="date" name="fecha_de" id="fecha_de" value="<?php echo $fecha_de; ?>" required>
				<label> A </label>
				<input type="date" name="fecha_a" id="fecha_a" value="<?php echo $fecha_a; ?>" required>
				<button type="submit" class="btn_view"><i class="fas fa-search"></i></button>
			</form>
		</div>
	<div class="containerTable">
		<table>
			<tr>
				<th>Fecha</th>
				<th>No. Recibo</th>
				<th>Codigo Item</th>
				<th>Cantidad</th>
				<th>Item</th>
				<th>Vendedor</th>
				<th>Costo Total </th>
				<th>Precio de Venta</th>
				<th>Venta Total</th>
				<th>Ganancia Bruta</th>
			</tr>
		<?php
			if($result > 0){
					$resultado = 0;
					$total=0;
				while ($data = mysqli_fetch_array($query)) {
					$venta_c = "venta_".$data["nofactura"];
					$idCliente = "cliente_".$data["codcliente"];
					$idventacript = encrypt($venta_c,$data["codcliente"]);
					$idclientecipt = encrypt($idCliente,$idventacript);

					
			?>
				<?php	$precio_venta_final = $data["precio_venta"] - $data["descuento"];  ?>
						<td><?php echo $data["fecha"]; ?></td>
						<td><?php echo $data["nofactura"]; ?></td>
						<td><?php echo $data["coditem"]; ?></td>
						<td><?php echo $data["cantidad"]; ?></td>
						<td><?php echo $data["producto"]; ?></td>
						<td><?php echo $data["nombre"]; ?></td>
						<td><?php echo "Bs."; echo $data["precio_compra"]; ?></td>
						<td><?php echo "Bs."; echo $data["precio"]; ?></td>
							<td><?php echo "Bs.";echo "$precio_venta_final" ?></td>
							<?php $gananciabruta = "$precio_venta_final" - $data["precio_compra"];  ?>
						
						<td><?php echo "Bs. $gananciabruta"; ?></td>
					
					<?php 
						$total = $total + $data["efectivo"];
						$resultado= "$resultado" + "$gananciabruta";
							
							?>
					
					
				</tr>
		<?php
				}
				?>
				
				<tr align="right">
					<td colspan="9"><P><h4><?php echo" Bs. $total"; ?></h4></p></td>
					<td align="left"><P><h3><?php echo" Bs. $resultado"; ?></h3></p></td>
				</tr>
				
				
			<?php	
			}
			
			
			else{
				echo '<tr><td colspan="9" align="center"><p><strong>No hay datos para mostrar</strong></p></td></tr>';
			}
			
			
		 ?>
		</table>
	</div>
	 
<?php
	if($total_registro != 0)
	{
 ?>
		<div class="paginador">
			<ul>
			<?php
				if($pagina != 1)
				{
			 ?>
				<li><a href="?pagina=<?php echo 1; ?>&<?php echo $buscar; ?>"><i class="fas fa-step-backward"></i></a></li>
				<li><a href="?pagina=<?php echo $pagina-1; ?>&<?php echo $buscar; ?>"><i class="fas fa-backward"></i></a></li>
			<?php
				}
				for ($i=1; $i <= $total_paginas; $i++) {
					# code...
					if($i == $pagina)
					{
						echo '<li class="pageSelected">'.$i.'</li>';
					}else{
						echo '<li><a href="?pagina='.$i.'&'.$buscar.'">'.$i.'</a></li>';
					}
				}

				if($pagina != $total_paginas)
				{
			 ?>
				<li><a href="?pagina=<?php echo $pagina + 1; ?>&<?php echo $buscar; ?>"><i class="fas fa-forward"></i></a></li>
				<li><a href="?pagina=<?php echo $total_paginas; ?>&<?php echo $buscar; ?>"><i class="fas fa-step-forward"></i></a></li>
			<?php } ?>
			</ul>
		</div>
<?php
	}
?>

	</section>
	<?php include "../includes/footer.php"; ?>
</body>
</html>