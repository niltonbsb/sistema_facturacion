<?php
	session_start();
	include "../../conexion.php";

	//Paginador
	$sql_registe = mysqli_query($conection,"SELECT COUNT(*) as total_registro FROM factura");
	$result_register = mysqli_fetch_array($sql_registe);
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
	//factura_serie = número de factura por serie
	date_default_timezone_set('America/Caracas'); 
	$fecha = date('Y-m-d');
	
	$query = mysqli_query($conection,"SELECT *
											
											 
										FROM  detallefactura as df, producto AS p, factura AS f, usuario AS u

										WHERE  f.usuario= u.idusuario AND f.fecha = '$fecha' and df.codproducto = p.codproducto and df.nofactura=f.nofactura 
										
										
										
									  	
		");

	$result = mysqli_num_rows($query);
	echo "$fecha";
 ?>

<!DOCTYPE html>
<html lang="en">
<head>
	<meta charset="UTF-8">
	<?php include "../includes/scripts.php"; ?>
	<title>Lista de ventas</title>
</head>
<body>
	<?php include "../includes/header.php"; ?>
	<section id="container">

		<h1><i class="far fa-file-alt"></i> Reporte de ventas</h1>
		<a href="nueva_venta.php" class="btn_new"><i class="fas fa-plus"></i></i> Nueva venta</a>
		<?php if( $result > 0  and ($_SESSION['rol'] == 1 or $_SESSION['rol'] == 2)){ ?>
		<form action="exportar.php" method="post" class="formExport" >
			<button type="submit" class="bntExport"> <i class="fas fa-file-excel"></i> Exportar todo</button>
		</form>
		<?php } ?>
		
		<div>
			<h5>Buscar por Fecha</h5>
			<form action="busqueda_reporte_venta.php" method="get" class="form_search_date">
				<label>De: </label>
				<input type="date" name="fecha_de" id="fecha_de" required>
				<label> A </label>
				<input type="date" name="fecha_a" id="fecha_a" required>
				<button type="submit" class="btn_view"><i class="fas fa-search"></i></button>
				<?php	$hoy = fechaC(); ?>
				<p class="fechaLarga"><h2><?php echo " Ventas Actual del Dia de hoy $hoy"; ?></h2></P>
		
			</form>
		
		</div>
	<div class="containerTable">
		<table>
			<tr>
				<th>Fecha.</th>
				<th>No. Recibo</th>
				<th>Codigo Item</th>
				<th>Cantidad</th>
				<th>Item</th>
				<th>Vendedor</th>
				<th>Costo Total </th>
				<th>Precio de Venta</th>
				<th>Venta Total</th>
				
				<th class="textcenter">Ganancia Bruta</th>
			</tr>
		<?php
			if($result > 0){
					$resultado = 0;
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
						<td><?php echo "Bs.";echo $data["precio_compra"]; ?></td>
						<td><?php echo "Bs.";echo $data["precio"]; ?></td>
						<td><?php echo "Bs.";echo "$precio_venta_final" ?></td>
							<?php $gananciabruta = "$precio_venta_final" - $data["precio_compra"];  ?>
						<td><?php echo "Bs.";echo "$gananciabruta"; ?></td>
					
					<?php $resultado= "$resultado" + "$gananciabruta";
							?>
					
					
				</tr>
		<?php
				}
				?>
				<table align="right"><tr><td align="right"><P><h2><?php echo" Bs. $resultado"; ?></h2></p></td></tr> </table>
		<?php
			}
			
			
			else{
				echo '<tr><td colspan="9" align="center"><p><strong>No hay Ventas el dia hoy</strong></p></td></tr>';
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
				<li><a href="?pagina=<?php echo 1; ?>"><i class="fas fa-step-backward"></i></a></li>
				<li><a href="?pagina=<?php echo $pagina-1; ?>"><i class="fas fa-backward"></i></a></li>
			<?php
				}
				for ($i=1; $i <= $total_paginas; $i++) {
					# code...
					if($i == $pagina)
					{
						echo '<li class="pageSelected">'.$i.'</li>';
					}else{
						echo '<li><a href="?pagina='.$i.'">'.$i.'</a></li>';
					}
				}

				if($pagina != $total_paginas)
				{
			 ?>
				<li><a href="?pagina=<?php echo $pagina + 1; ?>"><i class="fas fa-forward"></i></a></li>
				<li><a href="?pagina=<?php echo $total_paginas; ?> "><i class="fas fa-step-forward"></i></a></li>
			<?php } ?>
			</ul>
		</div>
	<?php } ?>
	</section>
	
	
	<?php include "../includes/footer.php"; ?>
</body>
</html>