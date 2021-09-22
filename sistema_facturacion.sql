-- phpMyAdmin SQL Dump
-- version 5.1.1
-- https://www.phpmyadmin.net/
--
-- Servidor: 127.0.0.1
-- Tiempo de generación: 22-09-2021 a las 02:19:13
-- Versión del servidor: 10.4.20-MariaDB
-- Versión de PHP: 7.3.29

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de datos: `sistema_facturacion`
--

DELIMITER $$
--
-- Procedimientos
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `actualizar_precio_producto` (IN `n_cantidad` INT, IN `n_precio` DECIMAL(10,2), IN `codigo` BIGINT, IN `id_entrada` BIGINT)  BEGIN
        DECLARE nueva_existencia int;
        DECLARE nuevo_total  decimal(10,2);
        DECLARE nuevo_precio_compra decimal(10,2);

        DECLARE cant_actual int;
        DECLARE pre_actual decimal(10,2);

        DECLARE actual_existencia int;
        DECLARE actual_precio_compra decimal(10,2);

        SELECT precio_compra, existencia INTO actual_precio_compra,actual_existencia FROM producto WHERE codproducto = codigo;

        SET nueva_existencia = actual_existencia + n_cantidad;
        SET nuevo_total = (actual_existencia * actual_precio_compra) + (n_cantidad * n_precio);
        SET nuevo_precio_compra = nuevo_total / nueva_existencia;

        UPDATE producto SET existencia = nueva_existencia,precio_compra = nuevo_precio_compra WHERE codproducto = codigo;
        UPDATE entradas SET precio_compra = n_precio WHERE correlativo = id_entrada;

        SELECT nueva_existencia,nuevo_precio_compra;

    END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `add_detalle_temp` (IN `codigo` INT, IN `canti` INT, IN `token` VARCHAR(50))  BEGIN
    DECLARE precio_actual decimal(10,2);
    DECLARE cant int;
    DECLARE nueva_cantidad int;
    DECLARE cant_actual int;
    DECLARE idtmp int;
    DECLARE cantcarrito int;
    DECLARE newcantcarrito int;
    DECLARE impid int;
    SET idtmp = 0;
    SET cantcarrito = 0;
    
    SELECT precio_compra,existencia,impuesto_id INTO precio_actual,cant_actual,impid FROM producto WHERE codproducto = codigo;
    SELECT IFNULL(SUM(cantidad),0) INTO cantcarrito FROM detalle_temp WHERE codproducto = codigo AND operacion = 1;
 
    SET newcantcarrito = cantcarrito + canti;
    IF cant_actual >= newcantcarrito THEN
        SELECT correlativo,cantidad INTO idtmp,cant FROM detalle_temp WHERE token_user = token AND codproducto = codigo AND operacion = 1;
        IF idtmp > 0 THEN
            SET nueva_cantidad = canti + cant;
            UPDATE detalle_temp SET cantidad = nueva_cantidad WHERE correlativo = idtmp; 
        ELSE
            INSERT INTO detalle_temp(token_user,codproducto,cantidad,precio_venta,impuestoid) VALUES(token,codigo,canti,precio_actual,impid);
        END IF;
        SELECT tmp.correlativo,tmp.codproducto,p.producto,p.descripcion,p.codebar,tmp.cantidad,tmp.precio_venta,i.impuesto FROM detalle_temp tmp
        INNER JOIN producto p
        ON tmp.codproducto = p.codproducto
        INNER JOIN impuesto i
        ON p.impuesto_id = i.idimpuesto
        WHERE tmp.token_user = token AND tmp.operacion = 1;
    ELSE
        SELECT cantidad;
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `anular_factura` (IN `no_factura` INT)  BEGIN
    	DECLARE existe_factura int;
        DECLARE registros int;
        DECLARE a int;
        
        DECLARE cod_producto int;
        DECLARE cant_producto int;
        DECLARE existencia_actual int;
        DECLARE nueva_existencia int;
        
        SET existe_factura = (SELECT COUNT(*) FROM factura WHERE nofactura = no_factura and estatus = 1);
        
        IF existe_factura > 0 THEN
        	CREATE TEMPORARY TABLE tbl_tmp (
                id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
                cod_prod BIGINT,
                cant_prod int);
                
                SET a = 1;
                
                SET registros = (SELECT COUNT(*) FROM detallefactura WHERE nofactura = no_factura);
                
                IF registros > 0 THEN
                	INSERT INTO tbl_tmp(cod_prod,cant_prod) SELECT codproducto,cantidad FROM detallefactura WHERE nofactura = no_factura;
                    
                    WHILE a <= registros DO
                    	SELECT cod_prod,cant_prod INTO cod_producto,cant_producto FROM tbl_tmp WHERE id = a;
                        SELECT existencia INTO existencia_actual FROM producto WHERE codproducto = cod_producto;
                        SET nueva_existencia = existencia_actual + cant_producto;
                        UPDATE producto SET existencia = nueva_existencia WHERE codproducto = cod_producto;
                        
                        SET a=a+1;
                    END WHILE;
                    
                    UPDATE factura SET estatus = 2 WHERE nofactura = no_factura;
                    DROP TABLE tbl_tmp;
                    SELECT * from factura WHERE nofactura = no_factura;
                   
                END IF;

        ELSE
        	SELECT 0 factura;
        END IF;
        
    END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `data_dashboard` (IN `fecha_actual` DATE, IN `user_id` INT)  BEGIN
		DECLARE usr int;
        DECLARE usuarios int;
        DECLARE clientes int;
        DECLARE proveedores int;
        DECLARE productos int;
        DECLARE pedidos int;
        DECLARE ventas_dia int;
        DECLARE venta_dia_efectivo DECIMAL(10,2);
        DECLARE venta_dia_tarjeta DECIMAL(10,2);
        SET usr = user_id;
        
        IF usr = 0 THEN
        	SELECT SUM(totalfactura) INTO venta_dia_efectivo FROM factura WHERE fecha = fecha_actual AND tipopago_id = 1 AND  estatus = 1;
        SELECT SUM(totalfactura) INTO venta_dia_tarjeta FROM factura WHERE fecha = fecha_actual AND tipopago_id = 2 AND estatus = 1;
        
        ELSE
        	SELECT SUM(totalfactura) INTO venta_dia_efectivo FROM factura WHERE fecha = fecha_actual AND tipopago_id = 1 AND usuario = usr AND estatus = 1;
        SELECT SUM(totalfactura) INTO venta_dia_tarjeta FROM factura WHERE fecha = fecha_actual AND tipopago_id = 2 AND usuario = usr AND estatus = 1;
        END IF;
        
        SELECT count(*) INTO usuarios FROM usuario WHERE estatus != 10;
        SELECT count(*) INTO clientes FROM cliente WHERE estatus != 10;
        SELECT count(*) INTO proveedores FROM proveedor WHERE estatus != 10;
        SELECT count(*) INTO productos FROM producto WHERE estatus != 10;
        SELECT count(*) INTO pedidos FROM pedido WHERE estatus != 10;
        SELECT COUNT(*) INTO ventas_dia FROM factura WHERE fecha = fecha_actual AND  estatus = 1;
       
       SELECT usuarios,clientes,proveedores,productos,pedidos,ventas_dia,venta_dia_efectivo,venta_dia_tarjeta;
        
    END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `del_detalle_temp` (IN `id_detalle` INT, IN `token` VARCHAR(50), IN `opc` INT)  BEGIN
    DELETE FROM detalle_temp WHERE correlativo = id_detalle;
    SELECT tmp.correlativo, tmp.codproducto,p.producto,p.descripcion,p.codebar,tmp.cantidad,tmp.precio_venta,tmp.precio_compra,i.impuesto FROM detalle_temp tmp
    INNER JOIN producto p
    ON tmp.codproducto = p.codproducto
    INNER JOIN impuesto i
    ON p.impuesto_id = i.idimpuesto
    WHERE tmp.token_user = token AND tmp.operacion = opc ;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `insertNoFactura` ()  BEGIN
  DECLARE a INT; 
  SET a = 1;
  WHILE a < 181 DO
	UPDATE factura SET factura_serie = a where nofactura = a;
    SET a = a + 1;
  END WHILE;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `procesar_compra` (IN `cod_usuario` INT, IN `cod_proveedor` INT, IN `compra` INT, IN `token` VARCHAR(50))  BEGIN

    DECLARE registros INT;
    DECLARE total DECIMAL(10,2);

    DECLARE nueva_existencia DECIMAL(10,2);
    DECLARE existencia_actual DECIMAL(10,2);

    DECLARE tmp_cod_producto int;
    DECLARE tmp_cant_producto DECIMAL(10,2);
    DECLARE tmp_pre_producto DECIMAL(10,2);
    DECLARE tmp_pre_venta DECIMAL(10,2);

    DECLARE a INT;
    SET a = 1;

    CREATE TEMPORARY TABLE tbl_tmp_compra (
            id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            cod_prod BIGINT,
            cant_prod int,
            pre_prod decimal(10,2),
            pre_venta decimal(10,2),
            cant_imp int
            );

    SET registros = (SELECT COUNT(*) FROM detalle_temp WHERE token_user = token AND operacion = 0);

    IF registros > 0 THEN
        INSERT INTO tbl_tmp_compra(cod_prod,cant_prod,pre_prod,pre_venta,cant_imp) SELECT codproducto,cantidad,precio_compra,precio_venta,impuestoid FROM detalle_temp WHERE token_user = token AND operacion = 0;

        INSERT INTO entradas(compra_id,codproducto,cantidad,precio_compra,precio,impuestoid) SELECT (compra) as no_compra,codproducto,cantidad,precio_compra,precio_venta,impuestoid FROM detalle_temp WHERE token_user = token and operacion = 0;

        WHILE a <= registros DO

            SELECT cod_prod,cant_prod,pre_prod,pre_venta INTO tmp_cod_producto,tmp_cant_producto,tmp_pre_producto,tmp_pre_venta FROM tbl_tmp_compra WHERE id = a;

            SELECT existencia INTO existencia_actual FROM producto WHERE codproducto = tmp_cod_producto;
            SET nueva_existencia = existencia_actual + tmp_cant_producto;

            UPDATE producto SET existencia = 							nueva_existencia,precio_compra = tmp_pre_venta WHERE codproducto = tmp_cod_producto;
            SET a=a+1;
        END WHILE;
        SET total = (SELECT SUM(cantidad * precio_compra) FROM detalle_temp WHERE token_user = token AND operacion = 0);
        UPDATE compra SET total = total WHERE id_compra = compra;
        DELETE FROM detalle_temp WHERE token_user = token AND operacion = 0;
        TRUNCATE TABLE tbl_tmp_compra;
        SELECT * FROM compra WHERE id_compra = compra;
    ELSE
        SELECT 0;
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `procesar_venta` (IN `cod_usuario` INT, IN `cod_cliente` INT, IN `token` VARCHAR(50), IN `tipo_pago` INT, IN `efectivo` DECIMAL(10,2), IN `descuento` DECIMAL(10,2), IN `fecha_r` VARCHAR(10), IN `idserie` BIGINT(20), IN `noFacturaSerie` BIGINT(20))  BEGIN
    DECLARE factura INT;

    DECLARE registros INT;
    DECLARE total DECIMAL(10,2);

    DECLARE nueva_existencia DECIMAL(10,2);
    DECLARE existencia_actual DECIMAL(10,2);

    DECLARE tmp_cod_producto int;
    DECLARE tmp_cant_producto DECIMAL(10,2);
    DECLARE a INT;
    SET a = 1;
    
    CREATE TEMPORARY TABLE tbl_tmp_tokenuser (
            id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            cod_prod BIGINT,
            cant_prod int,
            cant_imp int);
            
    SET registros = (SELECT COUNT(*) FROM detalle_temp WHERE token_user = token AND operacion = 1);
    
    IF registros > 0 THEN
        INSERT INTO tbl_tmp_tokenuser(cod_prod,cant_prod,cant_imp) SELECT codproducto,cantidad,impuestoid FROM detalle_temp WHERE token_user = token AND operacion = 1;
        
        INSERT INTO factura(serieid,factura_serie,fecha,usuario,codcliente,tipopago_id,efectivo,descuento) VALUES(idserie,noFacturaSerie,fecha_r,cod_usuario,cod_cliente,tipo_pago,efectivo,descuento);
        SET factura = LAST_INSERT_ID();
        
        INSERT INTO detallefactura(nofactura,codproducto,cantidad,precio_venta,impuestoid) SELECT (factura) as nofactura, codproducto,cantidad,precio_venta,impuestoid FROM detalle_temp WHERE token_user = token AND operacion = 1;
        
        WHILE a <= registros DO
            SELECT cod_prod,cant_prod INTO tmp_cod_producto,tmp_cant_producto FROM tbl_tmp_tokenuser WHERE id = a;
            SELECT existencia INTO existencia_actual FROM producto WHERE codproducto = tmp_cod_producto;
            
            SET nueva_existencia = existencia_actual - tmp_cant_producto;
            UPDATE producto SET existencia = nueva_existencia WHERE codproducto = tmp_cod_producto;
            
            SET a=a+1;
            
        END WHILE;
        
        SET total = (SELECT SUM(cantidad * precio_venta) FROM detalle_temp WHERE token_user = token AND operacion = 1);
        UPDATE factura SET totalfactura = total WHERE nofactura = factura;
        DELETE FROM detalle_temp WHERE token_user = token AND operacion = 1;
        TRUNCATE TABLE tbl_tmp_tokenuser;
        SELECT * FROM factura WHERE nofactura = factura;
    ELSE
        SELECT 0;
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `ventas_mensual` (IN `anio` INT, IN `meses` INT)  BEGIN
        DECLARE a INT;
        SET a = 1;

        CREATE TEMPORARY TABLE tbl_tmp_ventas (
                id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
                anio int,
                mes int,
            	cant_ventas int,
        		total decimal(10,2),
        		cant_compras int,
        		total_compras decimal(10,2));
         
         WHILE a <= meses DO
         	INSERT INTO tbl_tmp_ventas(anio,mes,cant_ventas,total) SELECT YEAR(fecha),MONTH(fecha),COUNT(nofactura),SUM(totalfactura) FROM factura WHERE MONTH(fecha) = a AND YEAR(fecha) = anio AND estatus = 1;
            
            

                SET a=a+1;
          END WHILE;
          SELECT * FROM tbl_tmp_ventas;

    END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `ventas_mensual_user` (IN `anio` INT, IN `meses` INT, IN `user` INT)  BEGIN

        DECLARE a INT;
        SET a = 1;

        CREATE TEMPORARY TABLE tbl_tmp_ventas (
                id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
                anio int,
                mes int,
                cant_ventas int,
                total decimal(10,2));
         
         WHILE a <= meses DO
            INSERT INTO tbl_tmp_ventas(anio,mes,cant_ventas,total) SELECT YEAR(fecha),MONTH(fecha),COUNT(nofactura),SUM(totalfactura) FROM factura WHERE MONTH(fecha) = a AND YEAR(fecha) = anio AND usuario = user AND estatus = 1;

                SET a=a+1;
          END WHILE;
          SELECT * FROM tbl_tmp_ventas;

    END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `categoria`
--

CREATE TABLE `categoria` (
  `idcategoria` bigint(20) NOT NULL,
  `categoria` varchar(100) NOT NULL,
  `descripcion` text NOT NULL,
  `subcategoria` bigint(20) NOT NULL DEFAULT 0,
  `parent_categoria` bigint(20) NOT NULL DEFAULT 0,
  `dateadd` datetime NOT NULL DEFAULT current_timestamp(),
  `usuarioid` bigint(20) NOT NULL,
  `estatus` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `categoria`
--

INSERT INTO `categoria` (`idcategoria`, `categoria`, `descripcion`, `subcategoria`, `parent_categoria`, `dateadd`, `usuarioid`, `estatus`) VALUES
(1, 'Herramientas Eléctricas', 'Herramientas Solo A Bateria', 0, 0, '2020-10-27 23:54:42', 1, 1),
(2, 'Herramientas Manuales', 'De Todos Los Tipos', 0, 0, '2021-08-05 10:57:45', 1, 1),
(3, 'Herramientas Medición', 'Niveles Láser, Distanciometros', 0, 0, '2021-09-01 17:07:03', 1, 1),
(4, 'Baterías', 'Todas Las Baterías Milwaukee M18 Y M12', 0, 0, '2021-09-06 10:31:42', 1, 1),
(5, 'Juego De Puntas', 'Juegos De Puntas Mix Milwaukee', 0, 0, '2021-09-06 14:59:13', 1, 1),
(6, 'Guantes', 'Toda Clase De Guantes Milwaukee', 0, 0, '2021-09-09 10:45:52', 1, 1),
(7, 'Linternas', 'Linternas De Todas Las Clases Milwaukee', 0, 0, '2021-09-13 15:45:06', 1, 1),
(8, 'Discos', 'Toda Clase De Discos', 0, 0, '2021-09-15 16:06:12', 1, 1),
(9, 'Cajas De Herramientas', 'Todo Tipo', 0, 0, '2021-09-16 17:27:41', 1, 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `categoria_producto`
--

CREATE TABLE `categoria_producto` (
  `id` bigint(20) NOT NULL,
  `categoria_id` bigint(20) NOT NULL,
  `producto_id` bigint(20) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `categoria_producto`
--

INSERT INTO `categoria_producto` (`id`, `categoria_id`, `producto_id`) VALUES
(60, 24, 24),
(80, 17, 28),
(81, 3, 26),
(82, 11, 26);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `cliente`
--

CREATE TABLE `cliente` (
  `idcliente` int(11) NOT NULL,
  `nit` varchar(20) NOT NULL,
  `nombre` varchar(80) DEFAULT NULL,
  `telefono` int(11) DEFAULT NULL,
  `correo` varchar(100) NOT NULL,
  `clave` varchar(255) NOT NULL,
  `cod_temp` varchar(200) NOT NULL,
  `direccion` text DEFAULT NULL,
  `dateadd` datetime NOT NULL DEFAULT current_timestamp(),
  `usuario_id` int(11) NOT NULL,
  `estatus` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `cliente`
--

INSERT INTO `cliente` (`idcliente`, `nit`, `nombre`, `telefono`, `correo`, `clave`, `cod_temp`, `direccion`, `dateadd`, `usuario_id`, `estatus`) VALUES
(1, 'CF', 'Consumidor Final', NULL, '', '', '', 'Ciudad', '2020-10-27 23:51:13', 1, 1),
(2, '123456', 'Francisco Arana', 45678974, 'ff@info.com', '', '', 'Ciudad', '2020-10-28 00:03:25', 1, 0),
(3, '', 'henry gonzales', 582, '', '', '', '573 NE 69th', '2021-08-05 14:22:35', 1, 0),
(4, '5229263017', 'jose gomez', 2147483647, '', '', '', 'Av. capitan ustariz', '2021-08-05 17:07:17', 1, 0),
(5, '5229263', 'Nilton', 2147483647, 'gomeznil1704@gmail.com', '', '', '573 NE 69th', '2021-08-05 17:51:46', 1, 0),
(6, '345671212', 'Antonio Perez', 71722615, 'anto@gmail.com', '', '', 'Capitan Ustariz', '2021-08-05 17:52:46', 1, 1),
(7, '852693', 'Henry Gonzalez', 703048952, 'henry@gmail.com', '', '', 'sacaba', '2021-08-09 08:51:37', 1, 0),
(8, '6405706', 'Jose Gomez', 67598258, '', '', '', 'Chimore #1543', '2021-08-17 17:18:16', 1, 0),
(9, '8691018', 'Jaime Jose Ledezma Fulguera', 75989599, 'jambletsillo@gmail.com', '', '', 'Av. siglo XX entre Elena Moyano y O. Barrientos', '2021-08-19 17:56:07', 1, 1),
(10, '6007210019', 'Grover Calle Flores', 75231633, 'asd@hotmail.com', '', '', 'La Paz', '2021-09-02 14:54:21', 1, 1),
(11, '6787689', 'Wilfredo Gutierrez', 8957452, '', '', '', 'heroinas', '2021-09-03 11:28:54', 1, 1),
(12, '2345', 'Anderson Cusi', 77758945, '', '', '', 'La Paz', '2021-09-06 10:36:44', 1, 1),
(13, '177906026', 'Retry SRL', 71280305, 'retryegmm@gmail.com', '', '', 'Av. 6 de marzo Nº 2152 La Paz', '2021-09-06 14:45:37', 1, 1),
(14, '154262027', 'Ende Andina S.A.M.', 4664001, '', '', '', 'Entre Rios', '2021-09-06 16:35:19', 1, 1),
(15, '3369652', 'Gabriel Soria Yoshinaga', 78855516, 'gaboyoshi@gmail.com', '', '', 'Cochabamba', '2021-09-08 11:25:34', 1, 1),
(16, '3748192', 'Daniel Vega', 76943003, 'daniel_vm83@hotmail.com', '', '', 'Cochabamba', '2021-09-08 15:32:27', 1, 1),
(17, '4051571', 'Marcelo Hurtado Velasquez', 72452708, '', '', '', 'Oruro', '2021-09-10 18:12:47', 1, 1),
(18, '5310073015', 'Oropeza', 68583373, 'xx@gmail.com', '', '', 'Cochabamba', '2021-09-13 16:27:50', 1, 1),
(19, '3035717', 'Florencio Mamani Aguilar', 74315630, 'qwert@hotmail.com', '', '', 'Santivañez', '2021-09-15 11:00:42', 1, 1),
(20, '7892965', 'Ojeda', 67455881, 'c.servonox@hotmail.com', '', '', 'Cochabamba', '2021-09-16 10:48:13', 1, 1),
(21, '7132834013', 'Luis Miguel Carbajal Salazar', 76829671, 'dextermaldonado17@gmail.com', '', '', 'Yacuiba', '2021-09-18 11:21:56', 1, 1),
(22, '3753760', 'Juvenal Carrrillo', 67524762, 'carrillo_juv@hotmail.com', '', '', 'Cochabamba', '2021-09-21 11:28:47', 1, 1),
(23, '4481010', 'Marvin Montes', 78560560, '', '', '', 'Santa Cruz', '2021-09-21 17:58:19', 1, 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `compra`
--

CREATE TABLE `compra` (
  `id_compra` int(11) NOT NULL,
  `documento_id` bigint(11) NOT NULL,
  `no_documento` int(11) NOT NULL,
  `serie` varchar(5) NOT NULL,
  `fecha_compra` datetime NOT NULL DEFAULT current_timestamp(),
  `proveedor_id` bigint(20) NOT NULL,
  `tipopago_id` int(11) NOT NULL,
  `total` decimal(10,2) NOT NULL,
  `usuario` bigint(20) NOT NULL,
  `dateadd` datetime NOT NULL DEFAULT current_timestamp(),
  `estatus` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `compra`
--

INSERT INTO `compra` (`id_compra`, `documento_id`, `no_documento`, `serie`, `fecha_compra`, `proveedor_id`, `tipopago_id`, `total`, `usuario`, `dateadd`, `estatus`) VALUES
(1, 2, 1585, '', '2021-08-05 00:00:00', 1, 1, '21000.00', 1, '2021-08-05 12:00:47', 1),
(2, 1, 111, '56', '2021-09-18 00:00:00', 1, 1, '12855.00', 1, '2021-09-18 11:51:39', 1),
(3, 1, 9, '12', '2021-09-18 00:00:00', 1, 1, '25000.00', 1, '2021-09-18 12:11:13', 1),
(4, 1, 3, '12', '2021-09-18 00:00:00', 1, 1, '48000.00', 1, '2021-09-18 20:46:05', 1),
(5, 1, 1, '12', '2021-09-18 00:00:00', 1, 1, '50000.00', 1, '2021-09-18 20:52:39', 1),
(6, 1, 4, '12', '2021-09-18 00:00:00', 1, 1, '24000.00', 1, '2021-09-18 21:34:38', 1),
(7, 1, 1, '12', '2021-09-18 00:00:00', 1, 1, '25000.00', 1, '2021-09-19 10:04:35', 1),
(8, 1, 1, '12', '2021-09-19 00:00:00', 1, 1, '24000.00', 1, '2021-09-19 10:20:17', 1),
(9, 1, 1, '12', '2021-09-19 00:00:00', 1, 1, '25000.00', 1, '2021-09-19 10:34:03', 1),
(10, 1, 1, '12', '2021-09-19 00:00:00', 1, 1, '24000.00', 1, '2021-09-19 10:39:18', 1),
(11, 1, 1, '12', '2021-09-19 00:00:00', 1, 1, '25000.00', 1, '2021-09-19 10:54:34', 1),
(12, 1, 78, '8', '2021-09-19 00:00:00', 1, 1, '24000.00', 1, '2021-09-19 11:10:22', 1),
(13, 1, 1, '12', '2021-09-20 00:00:00', 1, 1, '25000.00', 1, '2021-09-20 11:21:07', 1),
(14, 1, 100, '100', '2021-09-20 00:00:00', 1, 1, '24000.00', 1, '2021-09-20 11:24:36', 1),
(15, 1, 200, '1000', '2021-09-20 00:00:00', 1, 1, '25000.00', 1, '2021-09-20 11:59:43', 1),
(16, 1, 300, '100', '2021-09-20 00:00:00', 1, 1, '24000.00', 1, '2021-09-20 12:06:30', 1),
(17, 1, 400, '300', '2021-09-20 00:00:00', 1, 1, '2400.00', 1, '2021-09-20 12:15:42', 1),
(18, 1, 500, '300', '2021-09-20 00:00:00', 1, 1, '24000.00', 1, '2021-09-20 12:26:08', 1),
(19, 1, 1, '12', '2021-09-21 00:00:00', 1, 1, '24000.00', 1, '2021-09-21 14:24:36', 1),
(20, 1, 1, '1', '2021-09-21 00:00:00', 1, 1, '24000.00', 1, '2021-09-21 14:37:20', 1),
(21, 1, 14, '12', '2021-09-21 00:00:00', 1, 1, '25000.00', 1, '2021-09-21 16:22:45', 1),
(22, 1, 1, '7', '2021-09-21 00:00:00', 1, 1, '25000.00', 1, '2021-09-21 17:02:51', 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `configuracion`
--

CREATE TABLE `configuracion` (
  `id` bigint(20) NOT NULL,
  `nit` varchar(20) NOT NULL,
  `nombre` varchar(100) NOT NULL,
  `razon_social` varchar(200) NOT NULL,
  `logotipo` varchar(255) NOT NULL,
  `telefono` varchar(20) DEFAULT NULL,
  `whatsapp` varchar(20) DEFAULT NULL,
  `email` varchar(200) NOT NULL,
  `direccion` text NOT NULL,
  `impuesto` varchar(10) NOT NULL,
  `moneda` varchar(20) NOT NULL,
  `simbolo_moneda` varchar(5) NOT NULL,
  `zona_horaria` varchar(200) DEFAULT NULL,
  `sitio_web` text DEFAULT NULL,
  `email_factura` varchar(50) NOT NULL,
  `email_pedidos` varchar(80) NOT NULL,
  `facebook` varchar(200) DEFAULT NULL,
  `instagram` varchar(150) NOT NULL,
  `identificacion_cliente` varchar(20) DEFAULT NULL,
  `identificacion_tributaria` varchar(20) DEFAULT NULL,
  `separador_millares` varchar(1) NOT NULL,
  `separador_decimales` varchar(1) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `configuracion`
--

INSERT INTO `configuracion` (`id`, `nit`, `nombre`, `razon_social`, `logotipo`, `telefono`, `whatsapp`, `email`, `direccion`, `impuesto`, `moneda`, `simbolo_moneda`, `zona_horaria`, `sitio_web`, `email_factura`, `email_pedidos`, `facebook`, `instagram`, `identificacion_cliente`, `identificacion_tributaria`, `separador_millares`, `separador_decimales`) VALUES
(1, '6405706018', 'Herramienta Eléctrica Bolivia ', 'Unipersonal', 'logo_empresa.jpg', '4435693', '67598258', 'nilton_bsb@hotmail.com', 'Av. capitan ustariz Esq. Zoilo Linares', 'IVA', 'Bolivianos', 'Bs.', 'America/Caracas', 'https://www.herramientaelectrica.com.bo', 'nilton_bsb@hotmail.com', 'nilton_bsb@hotmail.com', 'https://www.facebook.com/MilwaukeeToolBolivia', 'https://www.instagram.com/milwaukeetoolbolivia/', 'CI o NIT', 'NIT', ',', ',');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `contacto_pedido`
--

CREATE TABLE `contacto_pedido` (
  `id_contacto` bigint(20) NOT NULL,
  `nombre` varchar(80) NOT NULL,
  `telefono` bigint(20) NOT NULL,
  `email` varchar(100) NOT NULL,
  `nit` varchar(20) NOT NULL,
  `nombre_fiscal` varchar(80) NOT NULL,
  `direccion` text NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `contacto_pedido`
--

INSERT INTO `contacto_pedido` (`id_contacto`, `nombre`, `telefono`, `email`, `nit`, `nombre_fiscal`, `direccion`) VALUES
(1, 'chsqui', 5916759825, 'nilton_bsb@hotmail.com', '5229263017', 'ende', 'Av. capitan ustariz'),
(2, 'gonzales', 12323, 'nilton1704@gmail.com', '7864556', 'elfec', '573 NE 69th'),
(3, 'Juan Pasten', 5673345, 'asd@hotmail.com', '3212354457', 'Semapa', 'heroinas'),
(4, 'alvaro ende', 56547896, 'sdf@hotmail.com', '5229263017', 'ende', 'Av. capitan ustariz'),
(5, 'gonzales', 5916759825, 'nilton_bsb@hotmail.com', '5229263017', 'xxxx', 'Av. capitan ustariz'),
(6, 'Alan Guitierrez', 71490884, 'alan.guitierrez@elfec.bo', '1023213028', 'Elfec SA', 'Heorinas'),
(7, 'Dexter Yalo Maldonado', 76829671, '123@gmail.com', '10635725', 'Dexter Yalo Maldonado', 'Yacuiba'),
(8, 'cARLOS', 45656767, 'sdf@hotmail.com', '89089089', 'Semapa', 'cIRCUNVALACION'),
(9, 'gonzales', 5916759825, 'nilton_bsb@hotmail.com', '5229263017', 'elfec', 'Av. capitan ustariz');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `detallefactura`
--

CREATE TABLE `detallefactura` (
  `correlativo` bigint(11) NOT NULL,
  `nofactura` bigint(11) DEFAULT NULL,
  `codproducto` int(11) DEFAULT NULL,
  `cantidad` int(11) DEFAULT NULL,
  `precio_venta` decimal(10,2) DEFAULT NULL,
  `impuestoid` bigint(20) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `detallefactura`
--

INSERT INTO `detallefactura` (`correlativo`, `nofactura`, `codproducto`, `cantidad`, `precio_venta`, `impuestoid`) VALUES
(1, 1, 2, 1, '3500.00', 1),
(2, 2, 2, 1, '3500.00', 1),
(6, 6, 2, 1, '3500.00', 1),
(7, 7, 2, 1, '3500.00', 1),
(8, 8, 16, 1, '2650.00', 1),
(9, 9, 18, 2, '350.00', 1),
(10, 10, 18, 1, '350.00', 1),
(11, 11, 2, 1, '3500.00', 1),
(12, 11, 80, 1, '430.00', 1),
(13, 12, 78, 1, '3200.00', 1),
(14, 13, 81, 1, '90.00', 1),
(15, 14, 82, 1, '1400.00', 1),
(16, 15, 83, 1, '1500.00', 1),
(17, 16, 84, 1, '660.00', 1),
(18, 17, 85, 1, '16500.00', 1),
(19, 18, 33, 1, '3500.00', 1),
(20, 19, 32, 1, '350.00', 1),
(21, 20, 44, 1, '170.00', 1),
(22, 21, 2, 1, '3500.00', 1),
(23, 22, 2, 1, '3500.00', 1),
(24, 23, 54, 1, '190.00', 1),
(25, 24, 178, 1, '380.00', 1),
(26, 25, 177, 1, '150.00', 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `detalle_pedido`
--

CREATE TABLE `detalle_pedido` (
  `id_detalle` bigint(20) NOT NULL,
  `pedido_id` bigint(20) NOT NULL,
  `codproducto` bigint(20) NOT NULL,
  `cantidad` int(11) NOT NULL,
  `precio_venta` decimal(10,2) NOT NULL,
  `impuestoid` bigint(20) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `detalle_pedido`
--

INSERT INTO `detalle_pedido` (`id_detalle`, `pedido_id`, `codproducto`, `cantidad`, `precio_venta`, `impuestoid`) VALUES
(1, 1, 2, 1, '3500.00', 1),
(2, 1, 16, 1, '2650.00', 1),
(3, 2, 2, 2, '3500.00', 1),
(4, 2, 16, 2, '2650.00', 1),
(5, 3, 16, 2, '2650.00', 1),
(6, 3, 2, 1, '3500.00', 1),
(7, 4, 50, 1, '200.00', 1),
(8, 5, 50, 2, '200.00', 1),
(9, 6, 18, 2, '290.00', 1),
(10, 7, 2, 1, '3500.00', 1),
(11, 8, 175, 1, '2650.00', 1),
(12, 8, 155, 1, '6300.00', 1),
(13, 8, 131, 1, '4200.00', 1),
(14, 9, 176, 1, '190.00', 1),
(15, 9, 175, 1, '2650.00', 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `detalle_temp`
--

CREATE TABLE `detalle_temp` (
  `correlativo` int(11) NOT NULL,
  `token_user` varchar(50) NOT NULL,
  `codproducto` int(11) NOT NULL,
  `cantidad` int(11) NOT NULL,
  `precio_venta` decimal(10,2) NOT NULL DEFAULT 0.00,
  `precio_compra` decimal(10,2) DEFAULT 0.00,
  `impuestoid` bigint(20) NOT NULL,
  `operacion` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `documento`
--

CREATE TABLE `documento` (
  `id_documento` int(11) NOT NULL,
  `descripcion` varchar(255) NOT NULL,
  `serie` varchar(10) NOT NULL,
  `no_inicial` bigint(20) NOT NULL,
  `no_final` bigint(20) NOT NULL,
  `date_add` datetime NOT NULL DEFAULT current_timestamp(),
  `usuario_id` bigint(20) NOT NULL,
  `estatus` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `entradas`
--

CREATE TABLE `entradas` (
  `correlativo` int(11) NOT NULL,
  `compra_id` bigint(20) NOT NULL,
  `codproducto` int(11) NOT NULL,
  `fecha` datetime NOT NULL DEFAULT current_timestamp(),
  `cantidad` int(11) NOT NULL,
  `precio_compra` decimal(10,2) NOT NULL,
  `precio` decimal(10,2) NOT NULL,
  `impuestoid` bigint(20) NOT NULL,
  `usuario_id` int(11) NOT NULL DEFAULT 1,
  `estado` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `entradas`
--

INSERT INTO `entradas` (`correlativo`, `compra_id`, `codproducto`, `fecha`, `cantidad`, `precio_compra`, `precio`, `impuestoid`, `usuario_id`, `estado`) VALUES
(1, 1, 2, '2021-08-05 12:00:47', 6, '2500.00', '3500.00', 1, 1, 1),
(2, 2, 2, '2021-09-18 11:51:39', 5, '2571.00', '3339.83', 1, 1, 1),
(3, 3, 2, '2021-09-18 12:11:13', 10, '2500.00', '3124.49', 1, 1, 1),
(4, 4, 2, '2021-09-18 20:46:05', 20, '2400.00', '2450.00', 1, 1, 1),
(5, 5, 2, '2021-09-18 20:52:39', 20, '2500.00', '2547.62', 1, 1, 1),
(6, 6, 2, '2021-09-18 21:34:39', 10, '2400.00', '2500.00', 1, 1, 1),
(7, 7, 2, '2021-09-19 10:04:35', 10, '2500.00', '2590.91', 1, 1, 1),
(8, 8, 2, '2021-09-19 10:20:17', 10, '2400.00', '2500.00', 1, 1, 1),
(9, 9, 2, '2021-09-19 10:34:03', 10, '2500.00', '2590.91', 1, 1, 1),
(10, 10, 2, '2021-09-19 10:39:18', 10, '2400.00', '2500.00', 1, 1, 1),
(11, 11, 2, '2021-09-19 10:54:34', 10, '2500.00', '2590.91', 1, 1, 1),
(12, 12, 2, '2021-09-19 11:10:22', 10, '2400.00', '2500.00', 1, 1, 1),
(13, 13, 2, '2021-09-20 11:21:07', 10, '2500.00', '2590.91', 1, 1, 1),
(14, 14, 2, '2021-09-20 11:24:37', 10, '2400.00', '2500.00', 1, 1, 1),
(15, 15, 2, '2021-09-20 11:59:43', 10, '2500.00', '2590.91', 1, 1, 1),
(16, 16, 2, '2021-09-20 12:06:30', 10, '2400.00', '2500.00', 1, 1, 1),
(17, 17, 2, '2021-09-20 12:15:42', 1, '2400.00', '2950.00', 1, 1, 1),
(18, 18, 2, '2021-09-20 12:26:08', 10, '2400.00', '2500.00', 1, 1, 1),
(19, 19, 2, '2021-09-21 14:24:36', 10, '2400.00', '2500.00', 1, 1, 1),
(20, 20, 2, '2021-09-21 14:37:20', 10, '2400.00', '2500.00', 1, 1, 1),
(21, 21, 2, '2021-09-21 16:22:45', 10, '2500.00', '2490.91', 1, 1, 1),
(22, 22, 2, '2021-09-21 17:02:51', 10, '2500.00', '2490.91', 1, 1, 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `factura`
--

CREATE TABLE `factura` (
  `nofactura` bigint(11) NOT NULL,
  `serieid` bigint(20) NOT NULL,
  `factura_serie` bigint(20) NOT NULL,
  `fecha` date NOT NULL,
  `usuario` int(11) DEFAULT NULL,
  `codcliente` int(11) DEFAULT NULL,
  `totalfactura` decimal(10,2) DEFAULT NULL,
  `descuento` decimal(20,2) NOT NULL,
  `tipopago_id` int(11) NOT NULL,
  `efectivo` decimal(10,2) NOT NULL,
  `dateadd` datetime NOT NULL DEFAULT current_timestamp(),
  `estatus` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `factura`
--

INSERT INTO `factura` (`nofactura`, `serieid`, `factura_serie`, `fecha`, `usuario`, `codcliente`, `totalfactura`, `descuento`, `tipopago_id`, `efectivo`, `dateadd`, `estatus`) VALUES
(1, 1, 1, '2021-08-05', 1, 1, '3500.00', '100.00', 1, '3600.00', '2021-08-05 12:05:00', 2),
(2, 1, 2, '2021-08-05', 1, 3, '3500.00', '150.00', 1, '3500.00', '2021-08-05 14:23:11', 1),
(6, 1, 6, '2021-08-19', 1, 9, '3500.00', '200.00', 1, '3500.00', '2021-08-19 17:58:08', 1),
(7, 1, 7, '2021-08-25', 1, 4, '3500.00', '700.00', 1, '3000.00', '2021-08-25 11:00:39', 1),
(8, 1, 8, '2021-08-25', 1, 8, '2650.00', '130.00', 1, '2520.00', '2021-08-25 14:41:07', 1),
(9, 1, 9, '2021-08-25', 1, 8, '700.00', '60.00', 1, '690.00', '2021-08-25 16:18:32', 1),
(10, 1, 10, '2021-08-26', 1, 4, '350.00', '30.00', 1, '320.00', '2021-08-26 10:25:22', 1),
(11, 1, 11, '2021-09-02', 1, 1, '3830.00', '200.00', 1, '3730.00', '2021-09-02 16:55:00', 1),
(12, 1, 12, '2021-09-03', 1, 11, '3200.00', '200.00', 1, '3000.00', '2021-09-03 11:29:08', 1),
(13, 1, 13, '2021-09-03', 1, 1, '90.00', '0.00', 1, '90.00', '2021-09-03 14:47:50', 1),
(14, 1, 14, '2021-09-06', 1, 12, '1400.00', '200.00', 1, '1200.00', '2021-09-06 10:37:11', 1),
(15, 1, 15, '2021-09-06', 1, 12, '1500.00', '100.00', 1, '1400.00', '2021-09-06 10:39:42', 1),
(16, 1, 16, '2021-09-06', 1, 12, '660.00', '160.00', 1, '500.00', '2021-09-06 10:41:30', 1),
(17, 1, 17, '2021-09-06', 1, 13, '16500.00', '500.00', 1, '16000.00', '2021-09-06 14:45:54', 1),
(18, 1, 18, '2021-09-06', 1, 14, '3500.00', '0.00', 1, '3500.00', '2021-09-06 16:35:33', 1),
(19, 1, 19, '2021-09-06', 1, 14, '350.00', '20.00', 1, '330.00', '2021-09-06 16:43:37', 1),
(20, 1, 20, '2021-09-06', 1, 14, '170.00', '10.00', 1, '160.00', '2021-09-06 16:44:16', 1),
(21, 1, 21, '2021-09-10', 1, 17, '3500.00', '250.00', 1, '3250.00', '2021-09-10 18:12:51', 1),
(22, 1, 22, '2021-09-13', 1, 18, '3500.00', '200.00', 1, '3300.00', '2021-09-13 16:33:43', 1),
(23, 1, 23, '2021-09-13', 1, 18, '190.00', '6.00', 1, '184.00', '2021-09-13 16:34:41', 1),
(24, 1, 24, '2021-09-21', 1, 1, '380.00', '30.00', 1, '350.00', '2021-09-21 17:55:48', 1),
(25, 1, 25, '2021-09-21', 1, 1, '150.00', '60.00', 1, '90.00', '2021-09-21 17:56:14', 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `facturas`
--

CREATE TABLE `facturas` (
  `idserie` bigint(20) NOT NULL,
  `cai` varchar(50) NOT NULL,
  `prefijo` varchar(20) NOT NULL,
  `periodo_inicio` date NOT NULL,
  `periodo_fin` date NOT NULL,
  `no_inicio` bigint(20) NOT NULL,
  `no_fin` bigint(20) NOT NULL,
  `ceros` int(11) NOT NULL,
  `usuarioid` bigint(20) NOT NULL,
  `dateadd` datetime NOT NULL DEFAULT current_timestamp(),
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `facturas`
--

INSERT INTO `facturas` (`idserie`, `cai`, `prefijo`, `periodo_inicio`, `periodo_fin`, `no_inicio`, `no_fin`, `ceros`, `usuarioid`, `dateadd`, `status`) VALUES
(1, '274101100737576', '000156', '2020-10-28', '2022-12-31', 1, 2000, 9, 1, '2020-10-28 00:02:32', 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `impuesto`
--

CREATE TABLE `impuesto` (
  `idimpuesto` bigint(20) NOT NULL,
  `impuesto` int(11) NOT NULL,
  `descripcion` varchar(255) NOT NULL,
  `dateadd` datetime NOT NULL DEFAULT current_timestamp(),
  `usuario_id` bigint(20) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `impuesto`
--

INSERT INTO `impuesto` (`idimpuesto`, `impuesto`, `descripcion`, `dateadd`, `usuario_id`, `status`) VALUES
(1, 0, 'Exento', '2020-10-27 23:57:11', 1, 1),
(2, 3, 'IMPUESTO 3%', '2020-10-27 23:57:45', 0, 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `marca`
--

CREATE TABLE `marca` (
  `idmarca` bigint(20) NOT NULL,
  `marca` varchar(100) NOT NULL,
  `descripcion` text NOT NULL,
  `dateadd` datetime NOT NULL DEFAULT current_timestamp(),
  `usuarioid` int(11) NOT NULL,
  `estatus` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `marca`
--

INSERT INTO `marca` (`idmarca`, `marca`, `descripcion`, `dateadd`, `usuarioid`, `estatus`) VALUES
(1, 'Milwaukee', 'Herramientas Eléctricas Y Manuales', '2020-10-27 23:54:05', 1, 1),
(2, 'Toughbuilt', 'Herramientas Manuales Y Bolsos', '2021-09-01 17:05:44', 1, 1),
(3, 'Diablo', 'Sierras Discos', '2021-09-15 16:00:15', 1, 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `pedido`
--

CREATE TABLE `pedido` (
  `id_pedido` bigint(20) NOT NULL,
  `fecha` date NOT NULL,
  `contacto_id` bigint(20) NOT NULL,
  `tipopago_id` int(11) NOT NULL,
  `total` decimal(10,2) NOT NULL DEFAULT 0.00,
  `estatus` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `pedido`
--

INSERT INTO `pedido` (`id_pedido`, `fecha`, `contacto_id`, `tipopago_id`, `total`, `estatus`) VALUES
(1, '2021-08-14', 1, 1, '6150.00', 1),
(2, '2021-08-14', 2, 1, '12300.00', 1),
(3, '2021-08-16', 3, 1, '8800.00', 1),
(4, '2021-09-01', 4, 2, '200.00', 3),
(5, '2021-09-01', 5, 1, '400.00', 1),
(6, '2021-09-17', 6, 1, '580.00', 1),
(7, '2021-09-18', 7, 1, '3500.00', 1),
(8, '2021-09-21', 8, 1, '13150.00', 1),
(9, '2021-09-21', 9, 1, '2840.00', 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `presentacion_producto`
--

CREATE TABLE `presentacion_producto` (
  `id_presentacion` bigint(20) NOT NULL,
  `presentacion` varchar(255) NOT NULL,
  `descripcion` text NOT NULL,
  `dateadd` datetime NOT NULL DEFAULT current_timestamp(),
  `usuarioid` bigint(20) NOT NULL,
  `estatus` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `presentacion_producto`
--

INSERT INTO `presentacion_producto` (`id_presentacion`, `presentacion`, `descripcion`, `dateadd`, `usuarioid`, `estatus`) VALUES
(1, 'Unidad', 'Productos Por Unidad', '2020-10-27 23:55:01', 1, 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `producto`
--

CREATE TABLE `producto` (
  `codproducto` int(11) NOT NULL,
  `codebar` varchar(50) NOT NULL,
  `producto` varchar(255) NOT NULL,
  `descripcion` text DEFAULT NULL,
  `categoria` bigint(20) NOT NULL,
  `marca_id` bigint(20) DEFAULT NULL,
  `presentacion_id` bigint(20) NOT NULL,
  `precio_compra` decimal(10,2) NOT NULL DEFAULT 0.00,
  `precio` decimal(10,2) NOT NULL DEFAULT 0.00,
  `impuesto_id` bigint(20) NOT NULL,
  `existencia` float NOT NULL DEFAULT 0,
  `existencia_minima` int(11) NOT NULL DEFAULT 1,
  `ubicacion_id` bigint(20) DEFAULT NULL,
  `date_add` datetime NOT NULL DEFAULT current_timestamp(),
  `usuario_id` int(11) NOT NULL,
  `estatus` int(11) NOT NULL DEFAULT 1,
  `foto` text DEFAULT NULL,
  `coditem` varchar(25) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `producto`
--

INSERT INTO `producto` (`codproducto`, `codebar`, `producto`, `descripcion`, `categoria`, `marca_id`, `presentacion_id`, `precio_compra`, `precio`, `impuesto_id`, `existencia`, `existencia_minima`, `ubicacion_id`, `date_add`, `usuario_id`, `estatus`, `foto`, `coditem`) VALUES
(2, '2975545645', 'Juego de Taladros Milwaukee M18', 'Juego de Taladros Milwaukee con dos baterias de 5 Amp , cargador y maletín', 1, 1, 1, '2490.91', '3500.00', 1, 11, 1, 1, '2021-08-05 11:02:01', 2, 1, 'img_ee9b47dbadcbe07d58f77dc6f2f84b81.jpg', '2997-22'),
(16, '45242536771', 'Taladro Percutor M18', 'Taladro Percutor Milwaukee M18 con dos baterías de 5 Amp, cargador 220v y maletín', 1, 1, 1, '2082.00', '2650.00', 1, 18, 1, 1, '2021-08-10 16:37:14', 1, 1, 'img_463cfaee1387d2f4e3a71140e6e706fa.jpg', '2804-22'),
(18, '45242251209', 'Alicate pelacable Milwaukee 6 en 1', 'Alicate pelacable 6 en 1 Milwaukee', 2, 1, 1, '135.00', '290.00', 1, 30, 1, 1, '2021-08-25 16:16:07', 1, 1, 'img_d2c5c14c86bea4c9d4c0593349ae1aee.jpg', '48-22-3079'),
(31, '45242509041', 'Juego de Taladros Milwaukee M12', 'Juego de Taladros Milwaukee M12 con bateria de 2 Amp. y Bateria de 4 Amp. cargador y Bolso', 1, 1, 1, '1617.00', '2350.00', 1, 18, 1, 1, '2021-08-30 16:13:45', 1, 1, 'img_87d91f784495b4193af4de09fd312016.jpg', '2598-22'),
(32, '45247235331', 'Brocas Titanio Milwaukee', 'Juego de Brocas de Titanio Milwaukee de 15 unidades de entrada Hexagonal', 2, 1, 1, '170.00', '350.00', 1, 10, 1, 1, '2021-08-30 16:30:22', 1, 1, 'img_5ef7b799e1bf5c3a505c477ec2ccd575.jpg', '48-89-4630'),
(33, '45242502338', 'Llave de Impacto 3/4', 'Llave de Impacto Milwaukee M18 3/4\" de 1500 libras de torque Solo herramienta Suelta', 1, 1, 1, '2050.00', '3500.00', 1, 2, 1, 1, '2021-08-30 16:59:08', 1, 1, 'img_04e6bfe967b3b9a5ddb2e5bb851d7317.jpg', '2864-20'),
(34, '984521321', 'Amoladora Milwaukee M18 4 1/2', 'Amoladora Milwaukee M18 de 4 1/2\" a 5\" de 8500 RPM solo herramienta, rapid stop y ajusta manual.', 1, 1, 1, '1557.00', '2200.00', 1, 2, 1, 1, '2021-08-30 17:14:36', 1, 1, 'img_96a10479e5660d366d56268123e5e4c7.jpg', '2783-20'),
(35, '45242187065', 'Juego de Brocas Forstner', 'Juego de Brocas Forstner Milwaukee 4 piezas', 2, 1, 1, '166.00', '260.00', 1, 3, 1, 1, '2021-08-30 17:43:18', 1, 1, 'img_db4f5635c67e7ef0b159d41ebaa7495a.jpg', '48-14-0004'),
(36, '45242356140', 'Corta Cable Milwaukee', 'Alicate Corta Cable Milwaukee con Agarre cómodo', 2, 1, 1, '176.00', '320.00', 1, 7, 1, 1, '2021-08-30 17:48:08', 1, 1, 'img_729a4bc27937b4c336396a728b0ee6ed.jpg', '48-22-6104'),
(37, '45242321162', 'Juego de Sierras 3 piezas', 'Juego de saca bocados Milwaukee 3 piezas para acero inoxidable', 2, 1, 1, '238.00', '420.00', 1, 6, 1, 1, '2021-08-31 15:46:22', 1, 1, 'img_61e1b4b71b9c420013ce344d8ccbc6e9.jpg', '49-22-4800'),
(38, '45242557813', 'Navaja Plegable con 50 hojas', 'Navaja con almacenamiento de hojas, 50 hojas de uso general', 2, 1, 1, '160.00', '280.00', 1, 10, 1, 1, '2021-08-31 15:50:20', 1, 1, 'img_ecc61063c01c04fe523175a7fdc2236d.jpg', '48-22-1504'),
(39, '45242514373', 'Destornillador 13 en 1', 'Destornillador 13 en 1 con agarre acolchado', 2, 1, 1, '110.00', '200.00', 1, 9, 1, 1, '2021-08-31 15:54:53', 1, 1, 'img_a0080d6d5299bfc66c1a7ea0ee5c9d7a.jpg', '48-22-2881'),
(40, '45242508075', 'Destornillador 11 en 1', 'Destornillador 11 en 1 con múltiples puntas', 2, 1, 1, '7.00', '150.00', 1, 4, 1, 1, '2021-08-31 15:58:25', 1, 1, 'img_8795ebbb18e86f8f5755b5521782d7ca.jpg', '48-22-2760'),
(41, '45242338092', 'Destornilladores de Precisión 4 piezas', 'Destornilladores de Precisión 4 piezas', 2, 1, 1, '111.00', '250.00', 1, 2, 1, 1, '2021-08-31 16:01:42', 1, 1, 'img_cb89e60ee4bfa0f3670cf17ff8c52b6c.jpg', '48-22-2604'),
(42, '45242265688', 'Juego de Eliminación de Materias 3 piezas', 'Juego de Eliminación de Materias 3 piezas', 2, 1, 1, '170.00', '290.00', 1, 1, 1, 1, '2021-08-31 16:06:14', 1, 1, 'img_b3fe9911a46a331a9533d6937bcdf57d.jpg', '49-22-5403'),
(43, '4524229684', 'Navaja tipo Abanico', 'Navaja tipo abanico Press and Flip', 2, 1, 1, '103.00', '150.00', 1, 7, 1, 1, '2021-08-31 16:12:14', 1, 1, 'img_2008e6e847b0ecbc6d407f2735acc740.jpg', '48-22-1990'),
(44, '45242559282', 'Navaja pico de Halcón', 'Navaja pico de Halcón con punta Redondeada fastback', 2, 1, 1, '114.00', '170.00', 1, 1, 1, 1, '2021-08-31 16:18:05', 1, 1, 'img_6dc1091a4f6c7ee7799acdf866b26353.jpg', '48-22-1526'),
(45, '4524255929', 'Navaja Plegable', 'Navaja Plegable Milwaukee con diseño Camuflado', 2, 1, 1, '130.00', '250.00', 1, 9, 1, 1, '2021-08-31 16:33:33', 1, 1, 'img_7809a60840fa3f3b355d3b09931c6c78.jpg', '48-22-1524'),
(46, '4524218003', 'Broca plana madera', 'Juego de Brocas Milwaukee planas universal 8 piezas', 2, 1, 1, '130.00', '300.00', 1, 9, 1, 1, '2021-08-31 16:56:15', 1, 1, 'img_01bca79fb645eefb99fa2d2ca4c4d2a9.jpg', '49-22-0175'),
(47, '45242534500', 'Navaja Fastback Asistida por Muelle', 'Navaja Fastback Asistida por Muelle Milwaukee con diseño Camuflado', 2, 1, 1, '186.00', '290.00', 1, 8, 1, 1, '2021-08-31 17:03:15', 1, 1, 'img_6089b158b8c838951eff3451c3da9204.jpg', '48-22-1535'),
(48, '45242555086', 'Juego de Cuchillas Utilitarias', 'Juego de Cuchillas Utilitarias Milwaukee 15 piezas', 2, 1, 1, '46.00', '90.00', 1, 8, 1, 1, '2021-08-31 17:08:04', 1, 1, 'img_6e550443f9ffa671145c00197e1383af.jpg', '48-22-1930'),
(49, '45242346820', 'Navaja para Ductos', 'Navaja para Ductos Milwaukee', 2, 1, 1, '126.00', '190.00', 1, 9, 1, 1, '2021-08-31 17:14:32', 1, 1, 'img_55726f4d26ac964683d06308ae31323f.jpg', '48-22-1920'),
(50, '45242573912', 'Navaja 6 en 1', 'Navaja Fastback Multiuso 6 en 1 Milwaukee', 2, 1, 1, '140.00', '200.00', 1, 10, 1, 1, '2021-08-31 17:19:24', 1, 1, 'img_d3f4177757334a989f0812c930f18f6e.jpg', '48-22-1505'),
(51, '4524230171', 'Destornillador de Demolición', 'Destornillador de Demolición de una sola pieza Milwaukee 2 piezas', 2, 1, 1, '94.00', '160.00', 1, 2, 1, 1, '2021-08-31 17:32:12', 1, 1, 'img_c4afd2f78a48e368cecf22b65aecaa6e.jpg', '48-22-2002'),
(52, '45242293780', 'Llaves para tuercas SAE', 'Juego de destornilladores para tuercas SAE (pulgadas) 4 piezas', 2, 1, 1, '149.00', '280.00', 1, 6, 1, 1, '2021-08-31 17:34:50', 1, 1, 'img_3053158fa8b9cdce18aaa9512e28ecf6.jpg', '48-22-2404'),
(53, '4524259270', 'Juego de Puntas 120 piezas', 'Juego de Puntas Milwaukee 120 piezas', 2, 1, 1, '250.00', '650.00', 1, 3, 1, 1, '2021-08-31 17:51:39', 1, 1, 'img_995067eea4da8d2b60bd48d1dfbb1edf.jpg', '48-32-4496'),
(54, '45242532674', 'Escuadra Milwaukee 180mm', 'Escuadra Milwaukee de 180mm', 2, 1, 1, '125.00', '190.00', 1, 14, 1, 1, '2021-09-01 09:51:24', 1, 1, 'img_5564fe94d2591221d990a143e903b555.jpg', 'MLSQ170'),
(55, '4524223835', 'Guia magnética con puntas 12 piezas', 'Guia para destornillador de 12 piezas Milwaukee', 2, 1, 1, '90.00', '230.00', 1, 12, 1, 1, '2021-09-01 10:06:18', 1, 1, 'img_bde44101543f48889816b892312a5a5f.jpg', '48-32-4507'),
(56, '4524229376', 'Destornilladores Aislados 1000v', 'Destornilladores Aislados 1000v Milwaukee 3 piezas', 2, 1, 1, '149.00', '320.00', 1, 2, 1, 1, '2021-09-01 10:09:33', 1, 1, 'img_295c75e637b646a696fff29817426d75.jpg', '48-22-2202'),
(57, '4524229375', 'Destornilladores Aislados 4 piezas', 'Destornilladores Aislados 1000v 4 piezas', 2, 1, 1, '312.00', '590.00', 1, 7, 1, 1, '2021-09-01 10:12:48', 1, 1, 'img_f0a24504f6b619ea8a5a59e425484ca2.jpg', '48-22-2204'),
(58, '045242544288', 'Nivel para fijar tubos', 'Nivel para fijar tubos Milwaukee', 2, 1, 1, '7.00', '100.00', 1, 5, 1, 1, '2021-09-01 10:18:04', 1, 1, 'img_a80823780f31459c7e4b094448aad9a7.jpg', '48-22-5001'),
(59, '45242356089', 'Alicate normal', 'Alicate normal Milwaukee', 2, 1, 1, '188.00', '250.00', 1, 2, 1, 1, '2021-09-01 10:22:51', 1, 1, 'img_536d09ff0bdd5b8d3b08a8834f91bb99.jpg', '48-22-6102'),
(60, '045242500765', 'Llave Hexagonal Acodada', 'Llave Hexagonal Acodada Milwaukee para plomeria', 2, 1, 1, '199.00', '370.00', 1, 9, 1, 1, '2021-09-01 10:27:34', 1, 1, 'img_0e4ed36a2b4b564c7b8212a2bef91f73.jpg', '48-22-7171'),
(61, '45242366538', 'Juego de Pinzas de Presión 6', 'Juego de Pinzas de Presión 6\" punta Larga y 10\" punta curva Milwaukee', 2, 1, 1, '149.00', '320.00', 1, 8, 1, 1, '2021-09-01 10:38:51', 1, 1, 'img_166c5e69b67af02ba456796fb3a33adc.jpg', '48-22-3602'),
(62, '045242349845', 'Llaves ajustables 2 piezas', 'Juego de Llaves Crecen Ajustables Milwaukee 2 Piezas 6\" y 10\"', 2, 1, 1, '189.00', '350.00', 1, 4, 1, 1, '2021-09-01 13:33:55', 1, 1, 'img_8a0636fc3c4de5d999c51d364b92e067.jpg', '48-22-7400'),
(63, '45242342327', 'Juego de pinzas de punta recta 2 piezas', 'Juego de pinzas de punta recta 2 piezas de 6\" y 10\" con capacidad de 1\" y 2\"', 2, 1, 1, '152.00', '340.00', 1, 6, 1, 1, '2021-09-01 14:21:35', 1, 1, 'img_e44f67f34d95ce3306a221db8c7e0e83.jpg', '48-22-6330'),
(64, '04524231706', 'Juego de Destornilladores 8 piezas', 'Juego de Destornilladores 8 piezas Milwaukee', 2, 1, 1, '213.00', '380.00', 1, 3, 1, 1, '2021-09-01 14:24:17', 1, 1, 'img_e4a623533ee60c2c35e2c5b860c45b82.jpg', '48-22-2018'),
(65, '45242476558', 'Juego de Hojas 16 piezas', 'Juego de Hojas de sierra sable 16 piezas Milwaukee', 2, 1, 1, '120.00', '420.00', 1, 2, 1, 1, '2021-09-01 14:29:18', 1, 1, 'img_dcb0e3b9b11367b81166dd6d16dd85b6.jpg', '49-22-1216'),
(66, '45242518661', 'Mini cortador plano', 'Mini cortador plano Milwaukee', 2, 1, 1, '62.00', '130.00', 1, 8, 1, 1, '2021-09-01 14:39:35', 1, 1, 'img_17cc56ee42dcde8adf43817eb37b6ecd.jpg', '48-22-6105'),
(67, '45242325047', 'Pinzas de presión Curvo 2 piezas', 'Juego de Pinzas de presión Curvo 2 piezas Milwaukee 7\" y 10\"', 2, 1, 1, '149.00', '320.00', 1, 5, 1, 1, '2021-09-01 14:46:18', 1, 1, 'img_9e07abd5dfd1005a1d25ebd7e9789a6c.jpg', '48-22-3402'),
(68, '4524232500', 'Pinza de presión recta 7', 'Pinza de presión recta 7\" Milwaukee', 2, 1, 1, '81.00', '165.00', 1, 6, 1, 1, '2021-09-01 14:54:49', 1, 1, 'img_603f56ed8e7bd1b288bd4b01d36ce0c3.jpg', '48-22-3507'),
(69, '45242324996', 'Pinza de presión recta 10', 'Pinza de presión recta 10\" Milwaukee', 2, 1, 1, '104.00', '260.00', 1, 4, 1, 1, '2021-09-01 14:58:42', 1, 1, 'img_89195eaeea9176005ad446a95c9f3cf6.jpg', '48-22-3510'),
(70, '45242324972', 'Pinza de Presión curva 7', 'Pinza de Presión curva 7\" Milwaukee', 2, 1, 1, '94.00', '170.00', 1, 4, 1, 1, '2021-09-01 15:05:10', 1, 1, 'img_5633aeb7f847c1feeff8ad1842002244.jpg', '48-22-3407'),
(71, '45242324965', 'Pinza de presión Curva 10', 'Pinza de presión Curva 10\" Milwaukee', 2, 1, 1, '110.00', '300.00', 1, 7, 1, 1, '2021-09-01 15:08:41', 1, 1, 'img_105283a7f8c3aefb491004e7cc751ebb.jpg', '48-22-3410'),
(72, '45242342297', 'Pinza de Punta Recta 12', 'Pinza de Punta Recta 12\" Milwaukee con Capacidad de 2 1/4\"', 2, 1, 1, '140.00', '350.00', 1, 12, 1, 1, '2021-09-01 15:23:08', 1, 1, 'img_57d0db19a7dd08e178534fcc6553a67f.jpg', '48-22-6312'),
(73, '045242342259', 'Pinza de Curva V de 12\"', 'Pinza de Curva V de 12\" Milwaukee con abertura 2 3/4\"', 2, 1, 1, '153.00', '360.00', 1, 1, 1, 1, '2021-09-01 16:20:30', 1, 1, 'img_a0bbbf92cba9a89a127382f64b877715.jpg', '48-22-6212'),
(74, '045242342242', 'Pinza de Punta en V de 10\"', 'Pinza de Punta en V de 10\" Milwaukee con abertura de 2\"', 2, 1, 1, '131.00', '220.00', 1, 13, 1, 1, '2021-09-01 16:23:49', 1, 1, 'img_8df1b84039ac4f6ad14d691d9cce690c.jpg', '48-22-6210'),
(75, '45242342204', 'Alicate Pinza de Corte 8', 'Pinza de Corte 8\" Milwaukee', 2, 1, 1, '137.00', '250.00', 1, 8, 1, 1, '2021-09-01 16:27:02', 1, 1, 'img_d61dcec5cd535467575396c3b9b599c3.jpg', '48-22-6108'),
(76, '045242356102', 'Alicate Pinza Crimpadora', 'Pinza Crimpadora Milwaukee', 2, 1, 1, '163.00', '270.00', 1, 5, 1, 1, '2021-09-01 16:29:43', 1, 1, 'img_fcb45454632fcd76b47ebc2c214356e1.jpg', '48-22-6103'),
(77, '45242568284', 'Nivel Laser 180º 2 lineas', 'Nivel Laser 180º 2 lineas luz verde a bateria pila', 3, 1, 1, '1752.00', '2750.00', 1, 5, 1, 1, '2021-09-01 16:33:08', 1, 1, 'img_817869c55e228cd72bda228580e7bc4a.jpg', '3521-21'),
(78, '45242568314', 'Nivel laser 180º 2 lineas con plomada', 'Nivel laser 180º 2 lineas luz verde con plomada Milwaukee con batería recargable', 3, 1, 1, '2206.00', '3200.00', 1, 2, 1, 1, '2021-09-01 17:01:10', 1, 1, 'img_808d8d21e95f66c31eff8484b6c4acaa.jpg', '3522-21'),
(79, '78978987', 'Nivel Laser 360º 3 lineas', 'Nivel Laser 360º de 3 lineas verde Milwaukee con bateria recargable', 3, 1, 1, '3793.00', '5800.00', 1, 2, 1, 1, '2021-09-01 17:03:57', 1, 1, 'img_776ffce37c2419421194c78a0b9a1c34.jpg', '3632-21'),
(80, '45242511433', 'Juego de Puntas 52 piezas', 'Juego de Puntas Milwaukee 52 piezas', 5, 1, 1, '200.00', '430.00', 1, 1, 1, 1, '2021-09-02 16:54:00', 1, 1, 'img_6af94fb4a6774d910b9f90a8bdea97be.jpg', '48-32-4025'),
(81, '45242540389', 'Topes para Drywall 4 Piezas', 'Topes para Drywall 4 Piezas Milwaukee de 1\"', 5, 1, 1, '44.00', '90.00', 1, 1, 1, 1, '2021-09-03 14:47:22', 1, 1, 'img_7089c4cc63ce7d2db18ba36df9492fa7.jpg', '48-32-2101'),
(82, '7986454521', 'Herramienta Oscilador M18', 'Herramienta Oscilador Milwaukee M18 con carbones solo herramienta', 1, 1, 1, '820.00', '1400.00', 1, 0, 1, 1, '2021-09-06 10:22:26', 1, 1, 'img_2fcb4e5e49cdfcae42b5103c91a21f40.jpg', '2626-20'),
(83, '78964512', 'Pistola para Drywall M18', 'Pilstola para Drywall Milwaukee M18 Solo Herramienta', 1, 1, 1, '899.00', '1500.00', 1, 1, 1, 1, '2021-09-06 10:25:27', 1, 1, 'img_2779d0a2c729fbda9de48e11c16d0411.jpg', '2866-20'),
(84, '98714785', 'Batería Milwaukee M18 5 Amp', 'Bateria Milwaukee de 5 Amp Milwaukee M18 una bateria', 4, 1, 1, '448.00', '670.00', 1, 4, 1, 1, '2021-09-06 10:30:51', 1, 1, 'img_3750a268bf965f42bcade1cf88f791cd.jpg', '48-11-1850'),
(85, '45242536580', 'Llave de Impacto 1', 'Llave de Impacto Milwaukee de 1\" M18, con dos baterias de 12 Amp, cargador y Bolso', 1, 1, 1, '9040.00', '16500.00', 1, 0, 1, 1, '2021-09-06 14:31:12', 1, 1, 'img_1b15de9bf468e3d3e8eb411277d039fe.jpg', '2868-22HD'),
(86, '045242542550', 'Sierra de Corte de 9\" M18', 'Sierra de Corte de 9\" Milwaukee M18 con dos baterias de 12 Amp, cargador Rapid Charge', 1, 1, 1, '6443.00', '9700.00', 1, 1, 1, 1, '2021-09-07 09:22:23', 1, 1, 'img_42ed37c285389965d7868ecd9351b867.jpg', '2786-22HD'),
(87, '45242556458', 'Guantes de Demolición de Impacto S', 'Guantes de Demolición de Impacto Milwaukee de 7\"/S', 6, 1, 1, '168.00', '280.00', 1, 11, 1, 1, '2021-09-09 11:01:41', 1, 1, 'img_65edbeba134a14cdc73b55c7cb532be6.jpg', '48-22-8750'),
(88, '045242556465', 'Guantes de Demolición de Impacto M', 'Guantes de Demolición de Impacto 8\"/M Milwaukee', 6, 1, 1, '168.00', '280.00', 1, 8, 1, 1, '2021-09-09 11:15:37', 1, 1, 'img_13f904166e92f8567d5535fed4353af3.jpg', '48-22-8751'),
(89, '045242556472', 'Guantes de Demolición de Impacto L', 'Guantes de Demolición de Impacto 9\"/L Milwaukee', 6, 1, 1, '168.00', '280.00', 1, 9, 1, 1, '2021-09-09 11:26:26', 1, 1, 'img_6362bca0cef2e4bffa429b9103749b5f.jpg', '48-22-8752'),
(90, '045242556618', 'Guantes de Nitrilo de nivel de corte de Impacto M', 'Guantes de Nitrilo de nivel de corte de Impacto M Milwaukee', 6, 1, 1, '110.00', '190.00', 1, 7, 1, 1, '2021-09-09 11:44:15', 1, 1, 'img_b4c3b8de70b1b03b0b857dee898dc520.jpg', '48-22-8971'),
(91, '045242556625', 'Guantes de Nitrilo de nivel de corte de Impacto L', 'Guantes de Nitrilo de nivel de corte de Impacto Milwaukee 9\"/L', 6, 1, 1, '110.00', '190.00', 1, 9, 1, 1, '2021-09-09 11:46:04', 1, 1, 'img_a195f283db7093eb3203c83df8bd4c13.jpg', '48-22-8972'),
(92, '45242556632', 'Guantes de Nitrilo de nivel de corte de Impacto XL', 'Guantes de Nitrilo de nivel de corte de Impacto XL Milwaukee', 6, 1, 1, '110.00', '190.00', 1, 11, 1, 1, '2021-09-10 10:07:58', 1, 1, 'img_9fee7f579228a7b80ed286df43040bc9.jpg', '48-22-8973'),
(93, '045242556816', 'Guantes de Desempeño S piel de cabra', 'Guantes de Desempeño 7\"/S piel de cabra Milwaukee', 6, 1, 1, '122.00', '280.00', 1, 18, 1, 1, '2021-09-10 10:21:24', 1, 1, 'img_d62b8d3eabf9525b54e6fc67b9708cb3.jpg', '48-73-0020'),
(94, '045242556823', 'Guantes de Desempeño M piel de cabra', 'Guantes de Desempeño 8\"/M piel de cabra Milwaukee', 6, 1, 1, '122.00', '280.00', 1, 6, 1, 1, '2021-09-10 10:22:53', 1, 1, 'img_44905889d1f77f85bef67830cc625e38.jpg', '48-73-0021'),
(95, '045242556830', 'Guantes de Desempeño L piel de cabra', 'Guantes de Desempeño 9\"/L piel de cabra Milwaukee', 6, 1, 1, '122.00', '280.00', 1, 11, 1, 1, '2021-09-10 10:24:36', 1, 1, 'img_4439d0d35af505a944a3ebef39ff0017.jpg', '48-73-0022'),
(96, '45242556564', 'Guantes de piel de cabra de Impacto M', 'Guantes de piel de cabra de Impacto 8\"/M Milwaukee', 6, 1, 1, '174.00', '290.00', 1, 10, 1, 1, '2021-09-10 10:38:58', 1, 1, 'img_bacfa20212aef00c6db94134a258bb18.jpg', '48-22-8781'),
(97, '045242556571', 'Guantes de piel de cabra de Impacto L', 'Guantes de piel de cabra de Impact 9\"/L Milwaukee', 6, 1, 1, '174.00', '290.00', 1, 10, 1, 1, '2021-09-10 10:43:11', 1, 1, 'img_4de8555166548449fa4a11b17507618f.jpg', '48-22-8782'),
(98, '45242556588', 'Guantes de piel de cabra de Impacto XL', 'Guantes de piel de cabra de Impacto 10\"/XL Milwaukee', 6, 1, 1, '174.00', '290.00', 1, 11, 1, 1, '2021-09-10 10:45:04', 1, 1, 'img_bacfa20212aef00c6db94134a258bb18.jpg', '48-22-8783'),
(99, '045242495085', 'Guantes de Alto Rendimiento S', 'Guantes de Alto Rendimiento 7\"/S Milwaukee', 6, 1, 1, '109.00', '180.00', 1, 11, 1, 1, '2021-09-10 10:58:48', 1, 1, 'img_80087166a278c146e1656b4e7e14dc77.jpg', '48-22-8725'),
(100, '045242501229', 'Guantes de Alto Rendimiento M', 'Guantes de Alto Rendimiento 8\"/M Milwaukee', 6, 1, 1, '108.00', '180.00', 1, 20, 1, 1, '2021-09-10 11:00:30', 1, 1, 'img_f62f72f1ad52fb35f3ffd655dc7cbae7.jpg', '48-22-8721'),
(101, '45242479887', 'Guantes de Alto Rendimiento L', 'Guantes de Alto Rendimiento 9\"/L Milwaukee', 6, 1, 1, '109.00', '180.00', 1, 19, 1, 1, '2021-09-10 11:02:24', 1, 1, 'img_47d298efd359c3b24e5268d95ece6276.jpg', '48-22-8722'),
(102, '045242479894', 'Guantes de Alto Rendimiento XL', 'Guantes de Alto Rendimiento 10\"/XL Milwaukee', 6, 1, 1, '109.00', '180.00', 1, 11, 1, 1, '2021-09-10 11:03:58', 1, 1, 'img_350ed550e06b221327d927e69222139a.jpg', '48-22-8723'),
(103, '987147852369', 'Juego de Taladros Milwaukee M18 One Key', 'Juego de Taladros Milwaukee One Key, con dos baterías de 5 Amp , cargador y maletín', 1, 1, 1, '2921.00', '3900.00', 1, 2, 1, 1, '2021-09-10 11:31:24', 1, 1, 'img_5325496af1cfca02c3340320b70f6cc0.jpg', '2996-22'),
(104, '45242570645', 'Linterna 800 Lúmenes Milwaukee', 'Linterna Compacta Milwaukee 800 lúmenes Recargable', 7, 1, 1, '450.00', '850.00', 1, 7, 1, 1, '2021-09-13 15:09:52', 1, 1, 'img_eed7abc0988713b68d76fa03ad10e6e4.jpg', '2160-21'),
(105, '45242570652', 'Linterna 1100 Lúmenes Milwaukee', 'Linterna Con enfoque Milwaukee 1100 lúmenes Recargable', 7, 1, 1, '565.00', '1150.00', 1, 1, 1, 1, '2021-09-13 15:44:20', 1, 1, 'img_6053cf671eb101f934520fbb5a2bc9c7.jpg', '2161-21'),
(106, '045242515998', 'Juego de llaves Milwaukee con trinquete 7 piezas', 'Juego de llaves Milwaukee con trinquete 7 piezas', 2, 1, 1, '711.00', '1200.00', 1, 5, 1, 1, '2021-09-13 16:55:34', 1, 1, 'img_5748a7169839468541febf850a6713e8.jpg', '48-22-9506'),
(107, '045242569977', 'Torre Luz Milwaukee M18 6000 lúmenes', 'Torre Luz Milwaukee M18 6000 lúmenes, también es cargador', 1, 1, 1, '2642.00', '3700.00', 1, 4, 1, 1, '2021-09-13 17:04:23', 1, 1, 'img_c1346a7bf1832a0b03564cd7e376c420.jpg', '2136-20'),
(108, '45242545230', 'Cargador y Batería 5 Amp. M18 Milwaukee', 'Cargador y Bateria 5 Amp Milwaukee M18', 4, 1, 1, '920.00', '1200.00', 1, 5, 1, 1, '2021-09-13 17:13:11', 1, 1, 'img_fbe2e1b06c623427c1651ad87e4217fd.jpg', '48-5950'),
(109, '045242324729', 'Force Logic Perforadora de Agujeros Milwaukee M18', 'Forcelogic Perforadora de Agujeros Milwaukee M18 de 1/2\"-4\" de 10 Toneladas', 1, 1, 1, '11570.00', '18500.00', 1, 1, 1, 1, '2021-09-15 08:07:41', 1, 1, 'img_0538431c74adeecd0400ffc9bcb7d2ab.jpg', '2676-23'),
(110, '045242570768', 'Alicate Pelacable 7 en 1 Milwaukee', 'Alicate Pelacable 7 en 1 Milwaukee de fuerza', 6, 1, 1, '185.00', '340.00', 1, 40, 1, 1, '2021-09-15 08:18:37', 1, 1, 'img_f86d436fbc8d8ac1e4bfcdc95e61197c.jpg', '48-22-3078'),
(111, '45242567591', 'Aspiradora Packout Milwaukee M18 Solo Herramienta', 'Aspiradora Packout Milwaukee M18 Solo Herramienta 2.5 Gl Húmedo/seco.', 1, 1, 1, '1325.00', '2150.00', 1, 5, 1, 1, '2021-09-15 08:30:07', 1, 1, 'img_e783688d7e03700b545865b9f2ed4de0.jpg', '0970-20'),
(112, '763409', 'Radio Packout Milwaukee M18', 'Radio Packout Milwaukee M18, tambien es Cargador, Solo Radio', 1, 1, 1, '2258.00', '3300.00', 1, 2, 1, 1, '2021-09-15 08:43:18', 1, 1, 'img_41195b277aa81604a68a123b28850f28.jpg', '2950-20'),
(113, '045242545674', 'Radio Milwaukee M12', 'Radio Milwaukee M12, también es cargador M12', 1, 1, 1, '826.00', '1300.00', 1, 3, 1, 1, '2021-09-15 08:50:17', 1, 1, 'img_7b46025bbb4b7daec79224316a46d0e2.jpg', '2951-20'),
(114, '045242487561', 'Punta Pozidriv Milwaukee 2\"', 'Punta Pozidriv Milwaukee 2\"', 2, 1, 1, '23.00', '40.00', 1, 100, 1, 1, '2021-09-15 09:51:15', 1, 1, 'img_6a99b0ef11ba39f57e867b71a7b262e5.jpg', '48-32-4832'),
(115, '045242487530', 'Punta Pozidriv Milwaukee 1\"', 'Punta Pozidriv Milwaukee 1\" Milwaukee 2 piezas', 2, 1, 1, '14.00', '35.00', 1, 80, 1, 1, '2021-09-15 09:58:22', 1, 1, 'img_d72fcda2566ae4a87fe8f625ef22687a.jpg', '48-32-4432'),
(116, '045242301980', 'Adaptador de 6\" Milwaukee', 'Adaptador portapuntas milwaukee de 6 \" Magnética', 2, 1, 1, '43.00', '120.00', 1, 30, 1, 1, '2021-09-15 10:03:21', 1, 1, 'img_52519dd374f506d9181d0def7cc62173.jpg', '48-32-4511'),
(117, '045242505623', 'Correa de Seguridad Milwaukee 10 Libras', 'Correa de Seguridad Milwaukee 10 Libras', 2, 1, 1, '136.00', '220.00', 1, 15, 1, 1, '2021-09-15 10:07:22', 1, 1, 'img_c8c1a2b02e9912eec270dee66fe0c851.jpg', '48-22-8810'),
(118, '045242505630', 'Correa para Herramientas Milwaukee 15 lbs', 'Correa para Herramientas Milwaukee 15 lbs', 2, 1, 1, '168.00', '280.00', 1, 10, 1, 1, '2021-09-15 10:11:03', 1, 1, 'img_2560ebfe760f34b83637ce3b937f5bac.jpg', '48-22-8815'),
(119, '045242365807', 'Broca SDS Plus 6mm Milwaukee', 'Broca SDS Plus 6mm Milwaukee', 2, 1, 1, '44.00', '65.00', 1, 30, 1, 1, '2021-09-15 10:21:24', 1, 1, 'img_4332625937d1c043a8c535604052779f.jpg', '48-20-8025'),
(120, '045242365852', 'Broca SDS Plus 8mm Milwaukee', 'Broca SDS Plus 8mm Milwaukee', 2, 1, 1, '45.00', '75.00', 1, 20, 1, 1, '2021-09-15 10:24:46', 1, 1, 'img_013294e8e8a55d654d2c4c79c4dee7c2.jpg', '48-20-8040'),
(121, '45242005154', 'Sierra Circular 7 1/4', 'Sierra Circular 7 1/4\" Milwaukee M18 Solo Herramienta Fuel Brushless', 1, 1, 1, '1611.00', '2600.00', 1, 9, 1, 1, '2021-09-15 11:21:22', 1, 1, 'img_b17a0ad1d26a19375968b216c3408742.jpg', '2732-20'),
(122, '45242552054', 'Flexo Milwaukee Stud 5 metros', 'Flexo Milwaukee Stud 5 metros/16\"', 2, 1, 1, '140.00', '270.00', 1, 20, 1, 1, '2021-09-15 11:25:54', 1, 1, 'img_a746e94ce85a70a5869c2ab79a0a9b05.jpg', '48-22-9717'),
(123, '45242505098', 'Broca Escalonada Milwaukee #8 de 1/2', 'Broca Escalonada Milwaukee #8 de 1/2\" - 1\" Hexagonal', 2, 1, 1, '345.00', '690.00', 1, 10, 1, 1, '2021-09-15 11:39:43', 1, 1, 'img_52738ff1b9b5baeb48ca3b32e1c77b38.jpg', '48-89-9248'),
(124, '045242579266', 'Broche para Nivel Laser Milwaukee', 'Broche para Nivel Laser Milwaukee', 2, 1, 1, '132.00', '250.00', 1, 10, 1, 1, '2021-09-15 12:02:56', 1, 1, 'img_467932d7ec5c87d40758e42a721bb612.jpg', '48-35-1313'),
(125, '045242520619', 'Brocas de Titanio 19 piezas en mm', 'Brocas de Titanio Milwaukee 19 piezas en mm', 2, 1, 1, '266.00', '450.00', 1, 10, 1, 1, '2021-09-15 12:12:55', 1, 1, 'img_d7f338fd0e281bbee4ad3e017cbdf1a7.jpg', '48-89-4860'),
(126, '45242563807', 'Sierra Podadora Milwaukee M12 6', 'Sierra Podadora Milwaukee M12 6\", Bateria de 4 Amp. y Cargador', 1, 1, 1, '1638.00', '2450.00', 1, 3, 1, 1, '2021-09-15 12:25:58', 1, 1, 'img_b7dd5f2d4140d670f03387a4a1469c69.jpg', '2527-21'),
(127, '4524256641', 'Amoladora Milwaukee M18 4 1/2', 'Amoladora Milwaukee M18 4 1/2\" a 5\" Paleta arriba, 2 baterias de 6 Amp, Cargador rapido y Bolso', 1, 1, 1, '2761.00', '4200.00', 1, 3, 1, 1, '2021-09-15 13:48:01', 1, 1, 'img_ae883514603fa87658d83ab001265103.jpg', '2881-22'),
(128, '45242537624', 'Amoladora Milwaukee M18 de 4 1/2', 'Amoladora Milwaukee de 4 1/2\" a 6\" con dos Baterías de 6 Amp, cargador rapido y Bolso', 1, 1, 1, '2880.00', '4400.00', 1, 5, 1, 1, '2021-09-15 13:56:31', 1, 1, 'img_5e3bd8ea9da7753ba30fc5925943a1ef.jpg', '2980-20'),
(129, '045242534081', 'Adaptador de angulo 90ª milwaukee', 'Adaptador de angulo 90ª Milwaukee', 2, 1, 1, '130.00', '280.00', 1, 20, 1, 1, '2021-09-15 14:04:37', 1, 1, 'img_92f56f8464299bf625fb73cf0689a4ab.jpg', '48-32-2390'),
(130, '045242238699', 'Punta de impacto de 6\" Milwaukee PH2', 'Punta de impacto de 6\" Milwaukee PH2', 2, 1, 1, '39.00', '90.00', 1, 30, 1, 1, '2021-09-15 14:09:32', 1, 1, 'img_46742a8929460c8362c7d1f6b396d21f.jpg', '48-32-4802'),
(131, '045242566402', 'Amoladora Milwaukee M18 4 1/2\" a 5\" Paleta abajo', 'Amoladora Milwaukee M18 4 1/2\" a 5\" paleta abajo, dos baterias de 6 amp, cargador rapido y Bolso.', 1, 1, 1, '2760.00', '4200.00', 1, 6, 1, 1, '2021-09-15 14:18:54', 1, 1, 'img_23d26d2ed7e48172fe62adf297f55454.jpg', '2880-22'),
(132, '045242482320', 'Moto Sierra Milwaukee 16\"', 'Moto Sierra Milwaukee 16\" con Batería de 12 Amp, cargador rapido y bolso', 1, 1, 1, '2946.00', '4600.00', 1, 2, 1, 1, '2021-09-15 14:25:51', 1, 1, 'img_7585bd53ef79a1125d8b7eafd8bea6f0.jpg', '2727-21HD'),
(133, '045242541010', 'Router Milwaukee M18 solo herramienta', 'Router Milwaukee M18 solo herramienta', 1, 1, 1, '1000.00', '2000.00', 1, 5, 1, 1, '2021-09-15 14:33:53', 1, 1, 'img_fab49dc9c4a0db16fb20ec810fc111b0.jpg', '2723-20'),
(134, '045242520961', 'Lijadora Orbital Milwaukee M18 solo Herramienta', 'Lijadora Orbital Milwaukee M18 solo Herramienta', 1, 1, 1, '700.00', '1300.00', 1, 5, 1, 1, '2021-09-15 14:40:38', 1, 1, 'img_e820377c62d2634c68079db09a29673d.jpg', '2648-20'),
(135, '045242534494', 'Navaja Fastback Milwaukee Asistida por Muelle', 'Navaja Fastback Milwaukee Asistida por Muelle', 2, 1, 1, '150.00', '300.00', 1, 5, 1, 1, '2021-09-15 14:56:35', 1, 1, 'img_31fa80592061cec839350a365c90530e.jpg', '48-22-1530'),
(136, '045242534487', 'Navaja Plegable con pico de Halcón Milwaukee', 'Navaja Plegable con pico de Halcón Milwaukee', 2, 1, 1, '100.00', '170.00', 1, 5, 1, 1, '2021-09-15 15:02:09', 1, 1, 'img_4ccf6dfbe6b643808be39670289a80d9.jpg', '48-22-1525'),
(137, '045242566280', 'Amoladora Milwaukee M18 4 1/2\" a 5\" paleta abajo, solo Herramienta', 'Amoladora Milwaukee M18 4 1/2\" a 5\" paleta abajo, solo Herramienta', 1, 1, 1, '700.00', '2000.00', 1, 9, 1, 1, '2021-09-15 15:10:26', 1, 1, 'img_007533778bf5237421dfb969a0f19103.jpg', '2880-20'),
(138, '75486', 'Atornillador de Impacto Milwaukee M12 Solo Herramienta', 'Atornillador de Impacto Milwaukee M12 Solo Herramienta', 1, 1, 1, '600.00', '950.00', 1, 4, 1, 1, '2021-09-15 15:19:49', 1, 1, 'img_3cbd10e146e3e43446c914cfb0b57378.jpg', '2553-20'),
(139, '7777777', 'Atornillador de Impacto Milwaukee M12', 'Atornillador de Impacto Milwaukee M12, dos baterias de 2 Amp, cargador y Maletin.', 1, 1, 1, '1011.00', '1600.00', 1, 1, 1, 1, '2021-09-15 15:26:01', 1, 1, 'img_6e533bceb4c479aa01a3697d6094a530.jpg', '2553-22'),
(140, '45242574377', 'Atornillador de Impacto Milwaukee M12', 'Atornillador de Impacto Milwaukee M12', 1, 1, 1, '838.00', '1300.00', 1, 5, 1, 1, '2021-09-15 15:32:56', 1, 1, 'img_13e75747964a821d2877112021eda321.jpg', '2553-21'),
(141, '8925075578', 'Disco para Melamina Diablo 7 1/2\" de 60 Dientes', 'Disco para Melamina Diablo 7 1/2\" de 60 Dientes', 8, 3, 1, '185.00', '380.00', 1, 13, 1, 1, '2021-09-15 15:48:08', 1, 1, 'img_2a27b1e635f3788b7aa1128527b1ce42.jpg', 'D0760'),
(142, '8925138853', 'Disco para Aluminio Diablo de 10\" de 100 dientes', 'Disco para Aluminio Diablo de 10\" de 100 dientes', 8, 3, 1, '510.00', '1000.00', 1, 8, 1, 1, '2021-09-15 15:59:51', 1, 1, 'img_6dcd82beee85a6cdbe2237d0a8f2393d.jpg', 'D10100N'),
(143, '045242472628', 'Bateria Milwaukee M12 6 Amp.', 'Batería Milwaukee M12 6 Amp.', 4, 1, 1, '100.00', '600.00', 1, 7, 1, 1, '2021-09-15 16:13:51', 1, 1, 'img_a0b5f49400b2bf78f3595fbc4e3da47e.jpg', '48-11-2460'),
(144, '45242330478', 'Taladro Percutor Milwaukee M12 Fuel 5/8\"', 'Taladro Percutor Milwaukee M12 Fuel 5/8\" con Batería de 4 Amp, cargador y Bolso', 1, 1, 1, '1564.00', '2500.00', 1, 3, 1, 1, '2021-09-15 16:17:57', 1, 1, 'img_54977715b807cef47592ca6348fb5441.jpg', '2416-21XC'),
(145, '008925020455', 'Disco Diablo para Aluminio 7 1/4\" de 56 dientes.', 'Disco Diablo para Aluminio 7 1/4\" de 56 dientes.', 8, 3, 1, '210.00', '420.00', 1, 7, 1, 1, '2021-09-15 16:30:07', 1, 1, 'img_7a94f7aebccc7d013f6f964a0c5bcb93.jpg', 'D0756N'),
(146, '045242333943', 'Mochila Milwaukee Clasica con base dura con 35 bolsillos', 'Mochila Milwaukee Clásica con base dura con 35 bolsillos', 2, 1, 1, '634.00', '980.00', 1, 5, 1, 1, '2021-09-15 17:38:40', 1, 1, 'img_a0e9a4d6e993673e7ff1dd3e3ac9edf1.jpg', '48-22-8200'),
(147, '45242544325', 'Cargador y Batería 3 Amp. M18 Milwaukee', 'Cargador y Batería 3 Amp. M18 Milwaukee', 4, 1, 1, '722.00', '1200.00', 1, 3, 1, 1, '2021-09-15 17:45:32', 1, 1, 'img_922662b75c93f4882cf067d7ab02ac7f.jpg', '48-59-1835'),
(148, '045242001569', 'Juego de Guías Milwaukee 3 piezas', 'Juego de Guías Milwaukee 3 piezas', 2, 1, 1, '99.00', '250.00', 1, 9, 1, 1, '2021-09-15 18:03:54', 1, 1, 'img_afd35830500e587a4b30ed94763fe033.jpg', '48-32-4519'),
(149, '045242577224', 'Cargador Milwaukee M18 con batería de 5 Amp y 2 Amp', 'Cargador Milwaukee M18 con batería de 5 Amp y 2 Amp', 4, 1, 1, '1088.00', '1400.00', 1, 1, 1, 1, '2021-09-15 18:08:40', 1, 1, 'img_c9dbaf3c85fd4578ae7f0d08f6e03eb8.jpg', '48-59-1850TP'),
(150, '45242544271', 'Esmeril de 1/4\" de angulo Milwaukee M12', 'Esmeril de 1/4\" de angulo Milwaukee M12, dos baterias de 2 Amp, cargador y Bolso', 1, 1, 1, '1840.00', '2750.00', 1, 2, 1, 1, '2021-09-16 12:10:30', 1, 1, 'img_2ba32758d0d2b40a747dfca8e6fceced.jpg', '2485-22'),
(151, '45242551637', 'Torquimetro Digital M12 de 1/2', 'Torquimetro Digital Milwaukee M12 de 1/2\" One Key. Solo Herramienta', 1, 1, 1, '4168.00', '6600.00', 1, 1, 1, 1, '2021-09-16 16:37:06', 1, 1, 'img_64e2f9d5d582d7fef321e84efb1126a9.jpg', '2466-20'),
(152, '045242286324', 'Porta Silicona Milwaukee M12', 'Porta Silicona Milwaukee M12 con una sola Batería.', 1, 1, 1, '1428.00', '2150.00', 1, 2, 1, 1, '2021-09-16 16:51:30', 1, 1, 'img_21301ca7b323c4463720527eb9c9005b.jpg', '2441-21'),
(153, '888888', 'Ingletadora Milwaukee M18 de 10', 'Ingletadora Milwaukee M18 de 10\", con batería de 8 Amp, cargador rápido', 1, 1, 1, '4900.00', '7200.00', 1, 2, 1, 1, '2021-09-16 16:56:29', 1, 1, 'img_0d389420fbb052a35f7caca4a022d2df.jpg', '2734-21HD'),
(154, '008925020424', 'Disco de diablo de 8 1/4\"', 'Disco de diablo de 8 1/4\" para madera acabado fino', 8, 3, 1, '224.00', '480.00', 1, 7, 1, 1, '2021-09-16 17:05:17', 1, 1, 'img_3e0a4f0e57fae7c144aeef7003b6a1e6.jpg', 'D0840X'),
(155, '77774444', 'Sierra de Mesa Milwaukee M18 8 1/4\" con bateria de 12 Amp. One Key', 'Sierra de Mesa Milwaukee M18 8 1/4\" con bateria de 12 Amp. One Key', 1, 1, 1, '5030.00', '6300.00', 1, 2, 1, 1, '2021-09-16 17:08:27', 1, 1, 'img_ca8cba433b3ad02f244afeb1b3fe0b7d.jpg', '2736-21HD'),
(156, '210916170924', 'Caja Milwaukee Packout para Herramientas con 3 Cajones', 'Caja Milwaukee Packout para Herramientas con 3 Cajones', 9, 1, 1, '1073.00', '1650.00', 1, 2, 1, 1, '2021-09-16 17:20:24', 1, 1, 'img_16d5b633c5281423b84b00f66e9e4094.jpg', '48-22-8443'),
(157, '25', 'Caja Milwaukee Packout para Herramientas con 2 Cajones', 'Caja Milwaukee Packout para Herramientas con 2 Cajones', 9, 1, 1, '997.00', '1550.00', 1, 10, 1, 1, '2021-09-16 17:25:29', 1, 1, 'img_8b941ab9569d083e50e385e4f64e4789.jpg', '48-22-8442'),
(158, '45242534531', 'Destornillador con Chicharra Milwaukee Pequeño 8 en 1', 'Destornillador con Chicharra Milwaukee Pequeño 8 en 1', 2, 1, 1, '125.00', '210.00', 1, 9, 1, 1, '2021-09-18 09:27:48', 1, 1, 'img_3335e53664fd7a066a8c2d533cb12758.jpg', '48-22-2330'),
(159, '045242534609', 'Destornillador 10 en 1 con chicharra Milwaukee', 'Destornillador 10 en 1 con chicharra Milwaukee', 2, 1, 1, '140.00', '290.00', 1, 6, 1, 1, '2021-09-18 09:56:08', 1, 1, 'img_96c595629188004fe37e76ba8866dfcb.jpg', '48-22-2322'),
(160, '045242552498', 'Tapones para Oidos con Banda Milwaukee', 'Tapones para Oidos con Banda Milwaukee', 2, 1, 1, '98.00', '190.00', 1, 5, 1, 1, '2021-09-18 10:32:07', 1, 1, 'img_14bbe5cb9908f8c64dae6792e48bf994.jpg', '48-73-3201'),
(161, '045242005802', 'Linterna de Cabeza Recargable 475 Lumenes USB', 'Linterna de Cabeza Recargable 475 Lúmenes USB Milwaukee', 1, 1, 1, '418.00', '750.00', 1, 3, 1, 1, '2021-09-18 10:40:11', 1, 1, 'img_a1c4468b3e477d507a8b879693eeb87c.jpg', '2111-21'),
(162, '045242605958', 'Punta de Impacto Milwaukee 3 1/2\" PH2', 'Punta de Impacto Milwaukee 3 1/2\" PH2', 5, 1, 1, '49.00', '85.00', 1, 10, 1, 1, '2021-09-18 10:53:25', 1, 1, 'img_92bbf04538214b059f5faed0653f4c47.jpg', '48-32-4662'),
(163, '045242606085', 'Punta de Impacto Milwaukee de 2\" PH2', 'Punta de Impacto Milwaukee de 2\" PH2', 5, 1, 1, '34.00', '40.00', 1, 10, 1, 1, '2021-09-18 10:58:39', 1, 1, 'img_187d0d3e035d33c52e5e868610c159d8.jpg', '48-32-4962'),
(164, '008925153955', 'Hoja para Caladora Diablo para madera corte fino', 'Hojas para Caladora madera corte fino 4 5/8\" largo DIABLO', 2, 3, 1, '23.00', '60.00', 1, 30, 1, 1, '2021-09-18 11:06:59', 1, 1, 'img_052a96985f3c5f210c382c6f6d86a079.jpg', 'DJT308BFP5'),
(165, '045242616787', 'Juego de Tira Lineas Milwaukee 2 piezas Rojo y Azul', 'Juego de Tira Lineas Milwaukee 2 piezas Rojo y Azul', 2, 1, 1, '125.00', '350.00', 1, 5, 1, 1, '2021-09-18 12:00:38', 1, 1, 'img_4003acc82a6cfa5931d34ff2792ff885.jpg', '48-22-3986W'),
(166, '045242325078', 'Abrazadera Milwaukee 6\" milwaukee C-clamp', 'Abrazadera Milwaukee 6\" milwaukee C-clamp', 2, 1, 1, '105.00', '200.00', 1, 1, 1, 1, '2021-09-20 08:55:07', 1, 1, 'img_ee398ffdac1ec48f49b75f9be4670f70.jpg', '48-22-3532'),
(167, '045242541362', 'Cargadro Simultanero Milwaukee M18 rapidCharge', 'Cargadro Simultanero Milwaukee M18 rapidCharge', 1, 1, 1, '950.00', '1500.00', 1, 2, 1, 1, '2021-09-20 08:59:15', 1, 1, 'img_037507434aa0bfdf4eb1126b442a202d.jpg', '48-59-1802'),
(168, '045242597826', 'Inflador Milwaukee M12 con bateria de 2 Amp y Cargador', 'Inflador Milwaukee M12 con bateria de 2 Amp y Cargador', 1, 1, 1, '830.00', '1850.00', 1, 3, 1, 1, '2021-09-20 09:06:31', 1, 1, 'img_7a0558a98ef6b535a44a9307e0c06d66.jpg', '2475-21CP'),
(169, '44555666', 'Porta Silicona Milwaukee M12 Solo Herramienta', 'Porta Silicona Milwaukee M12 Solo Herramienta', 1, 1, 1, '1175.00', '1650.00', 1, 1, 1, 1, '2021-09-20 09:13:08', 1, 1, 'img_dc23f8d030c3a50466cc69e5c0c23e65.jpg', '2441-20'),
(170, '996633', 'Sopladora Milwaukee M18 Solo herramienta', 'Sopladora Milwaukee M18 Solo herramienta', 1, 1, 1, '700.00', '900.00', 1, 0, 1, 1, '2021-09-20 09:17:10', 1, 1, 'img_9e83ac8c51f0fe1699701324706b8eb8.jpg', '0884-20'),
(171, '045242332434', 'Pulidora Milwaukee M12 Solo Herramienta.', 'Pulidora Milwaukee M12 Solo Herramienta.', 1, 1, 1, '1246.00', '1600.00', 1, 1, 1, 1, '2021-09-20 09:22:14', 1, 1, 'img_8d9abd9fdc59b26c61724ee53a224466.jpg', '2438-20'),
(172, '045242508174', 'Aspiradora tipo Mochila 3 en 1 Milwaukee M18 Solo Herramienta', 'Aspiradora tipo Mochila 3 en 1 Milwaukee M18 Solo Herramienta', 1, 1, 1, '2429.00', '3000.00', 1, 1, 1, 1, '2021-09-20 09:28:44', 1, 1, 'img_371a4790f77e7ef86a681d8a87a79b6d.jpg', '0885-20'),
(173, '8925135487', 'Disco Diablo para Metal Dentado de 14', 'Disco Diablo para Metal Dentado 14\"', 8, 3, 1, '676.00', '1200.00', 1, 2, 1, 1, '2021-09-20 09:39:19', 1, 1, 'img_30b31a93618d6d1b893609d6167209d6.jpg', 'D1490CF'),
(174, '77553399', 'Cargador Rapido Milwaukee M18/M12', 'Cargador Rápido Milwaukee M18/M12', 1, 1, 1, '340.00', '700.00', 1, 14, 1, 1, '2021-09-20 10:30:33', 1, 1, 'img_49e208151b3261fa866ca61853fcaccf.jpg', '48-59-1808'),
(175, '7553395511', 'Atornillador de Impacto Milwaukee 3 Generacion 1/4\" M18', 'Atornillador de Impacto Milwaukee M18 3 Generación 1/4\" M18', 1, 1, 1, '1666.00', '2650.00', 1, 5, 1, 1, '2021-09-20 10:33:10', 1, 1, 'img_34e5d2ee67216ff0f24b96158dbcef5f.jpg', '2853-22'),
(176, '045242302529', 'Adaptador de Dado para atornillador Milwaukee de 2\" 3 piezas', 'Adaptador de Dado para atornillador Milwaukee de 2\" 3 piezas', 2, 1, 1, '80.00', '190.00', 1, 8, 1, 1, '2021-09-20 10:38:53', 1, 1, 'img_1a9570d036648ebcf1cfe757257a2c01.jpg', '48-32-5033'),
(177, '045242552412', 'Lentes de Trabajo Milwaukee Oscuros', 'Lentes de Trabajo Milwaukee Oscuros', 2, 1, 1, '85.00', '150.00', 1, 1, 1, 1, '2021-09-21 17:46:50', 1, 1, 'img_39469a47519e153b56983f7ac4be3b71.jpg', '48-73-2005'),
(178, '008925137610', 'Disco par Corte Metal Diamantado Diablo 5\"', 'Disco par Corte Metal Diamantado Diablo 5\", corte Seco', 8, 3, 1, '111.00', '380.00', 1, 1, 1, 1, '2021-09-21 17:53:01', 1, 1, 'img_165cb0617f5effba29c81d0eb42a7457.jpg', 'DDD050DIA101F');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `proveedor`
--

CREATE TABLE `proveedor` (
  `codproveedor` int(11) NOT NULL,
  `nit` varchar(20) NOT NULL,
  `proveedor` varchar(100) DEFAULT NULL,
  `contacto` varchar(100) DEFAULT NULL,
  `telefono` bigint(11) DEFAULT NULL,
  `correo` varchar(100) NOT NULL,
  `direccion` text DEFAULT NULL,
  `date_add` datetime NOT NULL DEFAULT current_timestamp(),
  `usuario_id` int(11) NOT NULL,
  `estatus` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `proveedor`
--

INSERT INTO `proveedor` (`codproveedor`, `nit`, `proveedor`, `contacto`, `telefono`, `correo`, `direccion`, `date_add`, `usuario_id`, `estatus`) VALUES
(1, '123456', 'Milwaukee', 'Milwaukee', 12345645, 'milwaukee@info.com', 'EEUU', '2020-10-27 23:52:00', 1, 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `rol`
--

CREATE TABLE `rol` (
  `idrol` int(11) NOT NULL,
  `rol` varchar(20) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `rol`
--

INSERT INTO `rol` (`idrol`, `rol`) VALUES
(1, 'Administrador'),
(2, 'Supervisor'),
(3, 'Vendedor');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tipo_documento`
--

CREATE TABLE `tipo_documento` (
  `id_tipodocumento` int(11) NOT NULL,
  `documento` varchar(255) NOT NULL,
  `descripcion` text NOT NULL,
  `dateadd` datetime NOT NULL DEFAULT current_timestamp(),
  `usuario_id` bigint(20) NOT NULL,
  `estatus` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `tipo_documento`
--

INSERT INTO `tipo_documento` (`id_tipodocumento`, `documento`, `descripcion`, `dateadd`, `usuario_id`, `estatus`) VALUES
(1, 'Factura', 'Documento contable de facturación', '2019-08-21 00:44:52', 1, 1),
(2, 'Recibo', 'Recibo', '2019-08-21 00:46:07', 1, 1),
(3, 'Cupon', 'Documento de promociones', '2019-08-21 00:48:23', 1, 10),
(4, 'Ticket', 'Ticket', '2019-08-31 12:00:50', 1, 1),
(5, 'Envio', 'Para Envíos Rapidos', '2020-09-23 20:50:15', 49, 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tipo_pago`
--

CREATE TABLE `tipo_pago` (
  `id_tipopago` int(11) NOT NULL,
  `tipo_pago` varchar(50) NOT NULL,
  `descripcion` text NOT NULL,
  `date_add` datetime NOT NULL DEFAULT current_timestamp(),
  `estatus` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `tipo_pago`
--

INSERT INTO `tipo_pago` (`id_tipopago`, `tipo_pago`, `descripcion`, `date_add`, `estatus`) VALUES
(1, 'Efectivo', 'En moneda local', '2019-05-01 00:41:30', 1),
(2, 'Tarjeta', 'Tarjeta visa o mastercard', '2019-05-01 00:41:30', 1),
(3, 'Cheque', 'Cheque', '2020-02-09 14:01:09', 1),
(4, 'Cupón', 'Cupón promocional de tienda', '2020-02-09 14:02:43', 1),
(5, 'Tarjeta Debito', 'Tarjeta de debito', '2020-05-13 02:18:42', 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `ubicacion`
--

CREATE TABLE `ubicacion` (
  `id_ubicacion` bigint(20) NOT NULL,
  `ubicacion` varchar(200) NOT NULL,
  `descripcion` text NOT NULL,
  `dateadd` datetime NOT NULL DEFAULT current_timestamp(),
  `usuario_id` bigint(20) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `ubicacion`
--

INSERT INTO `ubicacion` (`id_ubicacion`, `ubicacion`, `descripcion`, `dateadd`, `usuario_id`, `status`) VALUES
(1, 'Cochabamba', 'Almacén De Cochabamba', '2019-11-19 11:35:14', 1, 1),
(4, 'Santa Cruz', 'Alamcen Santa Cruz', '2021-09-13 14:19:26', 1, 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `usuario`
--

CREATE TABLE `usuario` (
  `idusuario` int(11) NOT NULL,
  `dpi` varchar(20) NOT NULL,
  `nombre` varchar(50) DEFAULT NULL,
  `telefono` bigint(20) NOT NULL,
  `correo` varchar(100) DEFAULT NULL,
  `usuario` varchar(15) DEFAULT NULL,
  `clave` varchar(100) DEFAULT NULL,
  `cod_temp` varchar(200) DEFAULT NULL,
  `rol` int(11) DEFAULT NULL,
  `dateadd` datetime NOT NULL DEFAULT current_timestamp(),
  `estatus` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `usuario`
--

INSERT INTO `usuario` (`idusuario`, `dpi`, `nombre`, `telefono`, `correo`, `usuario`, `clave`, `cod_temp`, `rol`, `dateadd`, `estatus`) VALUES
(1, '6405706', 'Nilton Gomez', 67598258, 'nilton_bsb@hotmail.com', 'admin', 'ffbb13e28230a589195895243204f099', NULL, 1, '2020-10-27 22:57:19', 1),
(2, '6405706', 'Jose Gomez', 67598258, 'nilton1704@gmail.com', 'ngomez', 'ffbb13e28230a589195895243204f099', NULL, 2, '2021-08-05 10:59:37', 1),
(3, '123', 'Nilton Gomez', 5916759825, 'gomeznil1704@gmail.com', 'gomez', 'ffbb13e28230a589195895243204f099', NULL, 3, '2021-08-05 11:16:50', 1);

--
-- Índices para tablas volcadas
--

--
-- Indices de la tabla `categoria`
--
ALTER TABLE `categoria`
  ADD PRIMARY KEY (`idcategoria`);

--
-- Indices de la tabla `categoria_producto`
--
ALTER TABLE `categoria_producto`
  ADD PRIMARY KEY (`id`);

--
-- Indices de la tabla `cliente`
--
ALTER TABLE `cliente`
  ADD PRIMARY KEY (`idcliente`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- Indices de la tabla `compra`
--
ALTER TABLE `compra`
  ADD PRIMARY KEY (`id_compra`),
  ADD KEY `documento_id` (`documento_id`);

--
-- Indices de la tabla `configuracion`
--
ALTER TABLE `configuracion`
  ADD PRIMARY KEY (`id`);

--
-- Indices de la tabla `contacto_pedido`
--
ALTER TABLE `contacto_pedido`
  ADD PRIMARY KEY (`id_contacto`);

--
-- Indices de la tabla `detallefactura`
--
ALTER TABLE `detallefactura`
  ADD PRIMARY KEY (`correlativo`),
  ADD KEY `codproducto` (`codproducto`),
  ADD KEY `nofactura` (`nofactura`),
  ADD KEY `impuestoid` (`impuestoid`);

--
-- Indices de la tabla `detalle_pedido`
--
ALTER TABLE `detalle_pedido`
  ADD PRIMARY KEY (`id_detalle`),
  ADD KEY `pedido_id` (`pedido_id`) USING BTREE,
  ADD KEY `codproducto` (`codproducto`) USING BTREE,
  ADD KEY `impuestoid` (`impuestoid`);

--
-- Indices de la tabla `detalle_temp`
--
ALTER TABLE `detalle_temp`
  ADD PRIMARY KEY (`correlativo`),
  ADD KEY `nofactura` (`token_user`),
  ADD KEY `codproducto` (`codproducto`),
  ADD KEY `token_user` (`token_user`),
  ADD KEY `impuestoid` (`impuestoid`);

--
-- Indices de la tabla `documento`
--
ALTER TABLE `documento`
  ADD PRIMARY KEY (`id_documento`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- Indices de la tabla `entradas`
--
ALTER TABLE `entradas`
  ADD PRIMARY KEY (`correlativo`),
  ADD KEY `codproducto` (`codproducto`),
  ADD KEY `compra_id` (`compra_id`),
  ADD KEY `impuestoid` (`impuestoid`);

--
-- Indices de la tabla `factura`
--
ALTER TABLE `factura`
  ADD PRIMARY KEY (`nofactura`),
  ADD KEY `usuario` (`usuario`),
  ADD KEY `codcliente` (`codcliente`),
  ADD KEY `tipo_pago` (`tipopago_id`);

--
-- Indices de la tabla `facturas`
--
ALTER TABLE `facturas`
  ADD PRIMARY KEY (`idserie`),
  ADD KEY `usuarioid` (`usuarioid`);

--
-- Indices de la tabla `impuesto`
--
ALTER TABLE `impuesto`
  ADD PRIMARY KEY (`idimpuesto`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- Indices de la tabla `marca`
--
ALTER TABLE `marca`
  ADD PRIMARY KEY (`idmarca`);

--
-- Indices de la tabla `pedido`
--
ALTER TABLE `pedido`
  ADD PRIMARY KEY (`id_pedido`),
  ADD KEY `contacto_id` (`contacto_id`),
  ADD KEY `tipopago_id` (`tipopago_id`);

--
-- Indices de la tabla `presentacion_producto`
--
ALTER TABLE `presentacion_producto`
  ADD PRIMARY KEY (`id_presentacion`);

--
-- Indices de la tabla `producto`
--
ALTER TABLE `producto`
  ADD PRIMARY KEY (`codproducto`),
  ADD KEY `proveedor` (`marca_id`),
  ADD KEY `usuario_id` (`usuario_id`),
  ADD KEY `categoria_id` (`categoria`),
  ADD KEY `categoria` (`categoria`),
  ADD KEY `presentacion_id` (`presentacion_id`),
  ADD KEY `ubicacion_id` (`ubicacion_id`),
  ADD KEY `impuesto_id` (`impuesto_id`);

--
-- Indices de la tabla `proveedor`
--
ALTER TABLE `proveedor`
  ADD PRIMARY KEY (`codproveedor`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- Indices de la tabla `rol`
--
ALTER TABLE `rol`
  ADD PRIMARY KEY (`idrol`);

--
-- Indices de la tabla `tipo_documento`
--
ALTER TABLE `tipo_documento`
  ADD PRIMARY KEY (`id_tipodocumento`);

--
-- Indices de la tabla `tipo_pago`
--
ALTER TABLE `tipo_pago`
  ADD PRIMARY KEY (`id_tipopago`);

--
-- Indices de la tabla `ubicacion`
--
ALTER TABLE `ubicacion`
  ADD PRIMARY KEY (`id_ubicacion`);

--
-- Indices de la tabla `usuario`
--
ALTER TABLE `usuario`
  ADD PRIMARY KEY (`idusuario`),
  ADD KEY `rol` (`rol`);

--
-- AUTO_INCREMENT de las tablas volcadas
--

--
-- AUTO_INCREMENT de la tabla `categoria`
--
ALTER TABLE `categoria`
  MODIFY `idcategoria` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;

--
-- AUTO_INCREMENT de la tabla `categoria_producto`
--
ALTER TABLE `categoria_producto`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=83;

--
-- AUTO_INCREMENT de la tabla `cliente`
--
ALTER TABLE `cliente`
  MODIFY `idcliente` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=24;

--
-- AUTO_INCREMENT de la tabla `compra`
--
ALTER TABLE `compra`
  MODIFY `id_compra` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=23;

--
-- AUTO_INCREMENT de la tabla `contacto_pedido`
--
ALTER TABLE `contacto_pedido`
  MODIFY `id_contacto` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;

--
-- AUTO_INCREMENT de la tabla `detallefactura`
--
ALTER TABLE `detallefactura`
  MODIFY `correlativo` bigint(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=27;

--
-- AUTO_INCREMENT de la tabla `detalle_pedido`
--
ALTER TABLE `detalle_pedido`
  MODIFY `id_detalle` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=16;

--
-- AUTO_INCREMENT de la tabla `detalle_temp`
--
ALTER TABLE `detalle_temp`
  MODIFY `correlativo` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=633;

--
-- AUTO_INCREMENT de la tabla `documento`
--
ALTER TABLE `documento`
  MODIFY `id_documento` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `entradas`
--
ALTER TABLE `entradas`
  MODIFY `correlativo` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=23;

--
-- AUTO_INCREMENT de la tabla `factura`
--
ALTER TABLE `factura`
  MODIFY `nofactura` bigint(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=26;

--
-- AUTO_INCREMENT de la tabla `facturas`
--
ALTER TABLE `facturas`
  MODIFY `idserie` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `impuesto`
--
ALTER TABLE `impuesto`
  MODIFY `idimpuesto` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT de la tabla `marca`
--
ALTER TABLE `marca`
  MODIFY `idmarca` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `pedido`
--
ALTER TABLE `pedido`
  MODIFY `id_pedido` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;

--
-- AUTO_INCREMENT de la tabla `presentacion_producto`
--
ALTER TABLE `presentacion_producto`
  MODIFY `id_presentacion` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `producto`
--
ALTER TABLE `producto`
  MODIFY `codproducto` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=179;

--
-- AUTO_INCREMENT de la tabla `proveedor`
--
ALTER TABLE `proveedor`
  MODIFY `codproveedor` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `rol`
--
ALTER TABLE `rol`
  MODIFY `idrol` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `tipo_documento`
--
ALTER TABLE `tipo_documento`
  MODIFY `id_tipodocumento` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT de la tabla `tipo_pago`
--
ALTER TABLE `tipo_pago`
  MODIFY `id_tipopago` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT de la tabla `ubicacion`
--
ALTER TABLE `ubicacion`
  MODIFY `id_ubicacion` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT de la tabla `usuario`
--
ALTER TABLE `usuario`
  MODIFY `idusuario` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
