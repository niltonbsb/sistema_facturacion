<?php
		 session_start();
		if($_SESSION['rol'] != 1 and $_SESSION['rol'] != 2)
		{
			header("location: ../index.php");
		}

        $fecha = date('d-m-Y');
        $filename = 'lista_ventas';
        header("Content-Disposition: attachment; filename={$filename}_{$fecha}.xls");
        header("Content-type: application/force-download");
        header("Content-type: application/vdn.ms-excel");
        header("Pragma: public");
        print "\xEF\xBB\xBF"; // UTF-8 BOM

        include "../../conexion.php";
        include "../includes/functions.php";

        $filtro = $_POST['exportFilter'];


        $query = mysqli_query($conection,$filtro);
        $result = mysqli_num_rows($query);

        $style_row_head = 'style="border:1px solid #CCC;background-color:#5890cc;color:white;"';
        $style_row_data = 'style="border:1px solid #CCC; color:#555;"';
        $style_center = 'style="border:1px solid #CCC; color:#555; text-align:center;"';

        $dataHtml = '';
?>
        <table>
            <tr>
                <td colspan="9" style="font-size: 25pt; text-align:center;">REPORTE DE VENTAS</td>
            </tr>
            <tr>
                <th <?php echo $style_row_head;  ?> >No.</th>
                <th <?php echo $style_row_head;  ?> >No. Factura</th>
                <th <?php echo $style_row_head;  ?> >Fecha</th>
                <th <?php echo $style_row_head;  ?> ><?= strtoupper(IDENTIFICACION_TRIBUTARIA); ?></th>
                <th <?php echo $style_row_head;  ?> >Cliente</th>
                <th <?php echo $style_row_head;  ?> >Item</th>
                <th <?php echo $style_row_head;  ?> >Descripcion</th>
                <th <?php echo $style_row_head;  ?> >Cantidad</th>
                <th <?php echo $style_row_head;  ?> >Vendedor</th>
                <th <?php echo $style_row_head;  ?> >Tipo pago</th>
                <th <?php echo $style_row_head;  ?> >Estado</th>
                <th <?php echo $style_row_head;  ?> >Total</th>
            </tr>
<?php
        $i=1;
        $total= 0;
        if($result >0){
        while ($data = mysqli_fetch_array($query))
        {
            $estatus = ($data['estatus'] == 1 ) ? '<p style="color:green;">Pagado</p>' : '<p style="color:red;">Anulado</p>';
            
?>          
			<tr>
                <td <?php echo $style_row_data;  ?> > <?php echo $i;  ?> </td>
                <td <?php echo $style_row_data;  ?> > <?php echo $data["nofactura"];?></td>
                <td <?php echo $style_row_data;  ?> > <?php echo $data['fecha'];  ?> </td>
                <td <?php echo $style_center;  ?> > <?php echo $data['nit'];  ?> </td>
                <td <?php echo $style_row_data;  ?> > <?php echo $data['nombre'];  ?> </td>

                <td <?php echo $style_row_data;  ?> > <?php echo $data['coditem'];  ?> </td>
                <td <?php echo $style_row_data;  ?> > <?php echo $data['detalle_producto'];  ?> </td>
                <td <?php echo $style_row_data;  ?> > <?php echo $data['cantidad'];  ?> </td>

                <td <?php echo $style_row_data;  ?> > <?php echo $data['vendedor'];;  ?> </td>
                <td <?php echo $style_center;  ?> > <?php echo $data['tipo_pago'];  ?> </td>
                <td <?php echo $style_center;  ?> > <?php echo $estatus;  ?> </td>
                <td <?php echo $style_row_data;  ?> > <?php echo $data['totalfactura'];  ?> </td>
            </tr>
<?php
            $total += $data['totalfactura'];
            $i++;
        }
    }
 ?>
            <tr>
                <td colspan="8">Total:</td>
                <td><?= $total; ?></td>
            </tr>
        </table>