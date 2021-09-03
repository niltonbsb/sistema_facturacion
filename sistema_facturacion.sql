-- phpMyAdmin SQL Dump
-- version 5.1.1
-- https://www.phpmyadmin.net/
--
-- Servidor: 127.0.0.1
-- Tiempo de generación: 03-09-2021 a las 23:16:21
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
        DECLARE nuevo_precio decimal(10,2);

        DECLARE cant_actual int;
        DECLARE pre_actual decimal(10,2);

        DECLARE actual_existencia int;
        DECLARE actual_precio decimal(10,2);

        SELECT precio,existencia INTO actual_precio,actual_existencia FROM producto WHERE codproducto = codigo;

        SET nueva_existencia = actual_existencia + n_cantidad;
        SET nuevo_total = (actual_existencia * actual_precio) + (n_cantidad * n_precio);
        SET nuevo_precio = nuevo_total / nueva_existencia;

        UPDATE producto SET existencia = nueva_existencia,precio_compra = n_precio, precio = nuevo_precio WHERE codproducto = codigo;
        UPDATE entradas SET precio_compra = n_precio, precio = nuevo_precio WHERE correlativo = id_entrada;

        SELECT nueva_existencia,nuevo_precio;

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
    
    SELECT precio,existencia,impuesto_id INTO precio_actual,cant_actual,impid FROM producto WHERE codproducto = codigo;
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

            UPDATE producto SET existencia = nueva_existencia,precio_compra = tmp_pre_producto, precio = tmp_pre_venta WHERE codproducto = tmp_cod_producto;
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
(3, 'Herramientas Medición', 'Niveles Láser, Distanciometros', 0, 0, '2021-09-01 17:07:03', 1, 1);

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
(2, '123456', 'Francisco Arana', 45678974, 'ff@info.com', '', '', 'Ciudad', '2020-10-28 00:03:25', 1, 1),
(3, '', 'henry gonzales', 582, '', '', '', '573 NE 69th', '2021-08-05 14:22:35', 1, 1),
(4, '5229263017', 'jose gomez', 2147483647, '', '', '', 'Av. capitan ustariz', '2021-08-05 17:07:17', 1, 1),
(5, '5229263', 'Nilton', 2147483647, 'gomeznil1704@gmail.com', '', '', '573 NE 69th', '2021-08-05 17:51:46', 1, 1),
(6, '345671212', 'Antonio Perez', 71722615, 'anto@gmail.com', '', '', 'Capitan Ustariz', '2021-08-05 17:52:46', 1, 1),
(7, '852693', 'Henry Gonzalez', 703048952, 'henry@gmail.com', '', '', 'sacaba', '2021-08-09 08:51:37', 1, 1),
(8, '6405706', 'Jose Gomez', 67598258, '', '', '', 'Chimore #1543', '2021-08-17 17:18:16', 1, 1),
(9, '8691018', 'Jaime Jose Ledezma Fulguera', 75989599, 'jambletsillo@gmail.com', '', '', 'Av. siglo XX entre Elena Moyano y O. Barrientos', '2021-08-19 17:56:07', 1, 1),
(10, '6007210019', 'Grover Calle Flores', 75231633, 'asd@hotmail.com', '', '', 'La Paz', '2021-09-02 14:54:21', 1, 1),
(11, '6787689', 'Wilfredo Gutierrez', 8957452, '', '', '', 'heroinas', '2021-09-03 11:28:54', 1, 1);

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
(1, 2, 1585, '', '2021-08-05 00:00:00', 1, 1, '21000.00', 1, '2021-08-05 12:00:47', 1);

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
(1, '6405706018', 'Herramienta Eléctrica Bolivia ', 'Unipersonal', 'logo_empresa.jpg', '6759825', '67598258', 'nilton_bsb@hotmail.com', 'Av. capitan ustariz Esq. Zoilo Linares', 'IVA', 'Bolivianos', 'Bs.', 'America/Caracas', 'https://www.herramientaelectrica.com.bo', 'nilton_bsb@hotmail.com', 'nilton_bsb@hotmail.com', 'https://www.facebook.com/MilwaukeeToolBolivia', '', 'CI o NIT', 'NIT', ',', ',');

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
(5, 'gonzales', 5916759825, 'nilton_bsb@hotmail.com', '5229263017', 'xxxx', 'Av. capitan ustariz');

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
(14, 13, 81, 1, '90.00', 1);

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
(8, 5, 50, 2, '200.00', 1);

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
(1, 1, 2, '2021-08-05 12:00:47', 6, '3500.00', '3500.00', 1, 1, 1);

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
(11, 1, 11, '2021-09-02', 1, 1, '3930.00', '200.00', 1, '3730.00', '2021-09-02 16:55:00', 1),
(12, 1, 12, '2021-09-03', 1, 11, '3200.00', '200.00', 1, '3000.00', '2021-09-03 11:29:08', 1),
(13, 1, 13, '2021-09-03', 1, 1, '90.00', '0.00', 1, '90.00', '2021-09-03 14:47:50', 1);

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
(2, 'Toughbuilt', 'Herramientas Manuales Y Bolsos', '2021-09-01 17:05:44', 1, 1);

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
(5, '2021-09-01', 5, 1, '400.00', 1);

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
(2, '2975545645', 'Juego de Taladros Milwaukee M18', 'Juego de Taladros Milwaukee con dos baterias de 5 Amp , cargador y maletín', 1, 1, 1, '2500.00', '3500.00', 1, 26, 1, 1, '2021-08-05 11:02:01', 2, 1, 'img_ee9b47dbadcbe07d58f77dc6f2f84b81.jpg', '2997-22'),
(16, '89990', 'Taladro Percutor M18', 'Taladro Percutor con dos baterias de 5 Amp, cargafor 220v y maletin', 1, 1, 1, '1950.00', '2650.00', 1, 8, 1, 1, '2021-08-10 16:37:14', 1, 1, 'img_463cfaee1387d2f4e3a71140e6e706fa.jpg', '2804-22'),
(18, '345678', 'Alicate pelacable Milwaukee', 'Alicate pelacable 6 en 1', 2, 1, 1, '200.00', '350.00', 1, 47, 1, 1, '2021-08-25 16:16:07', 1, 1, 'img_d2c5c14c86bea4c9d4c0593349ae1aee.jpg', '48-22-3079'),
(31, '78654', 'Juego de Taladros Milwaukee M12', 'Juego de Taladros Milwaukee M12 con bateria de 2 Amp. y Bateria de 4 Amp. cargador y Bolso', 1, 1, 1, '1700.00', '2350.00', 1, 15, 1, 1, '2021-08-30 16:13:45', 1, 1, 'img_87d91f784495b4193af4de09fd312016.jpg', '2598-22'),
(32, '45247235331', 'Brocas Titanio Milwaukee', 'Juego de Brocas Milwaukee de 15 unidades de entrada Hexagonal', 2, 1, 1, '170.00', '350.00', 1, 11, 1, 1, '2021-08-30 16:30:22', 1, 1, 'img_5ef7b799e1bf5c3a505c477ec2ccd575.jpg', '48-89-4630'),
(33, 'J40AD20160', 'Llave de Impacto 3/4', 'Llave de Impacto Milwaukee M18 3/4\" de 1500 libras de torque Solo herramienta Suelta', 1, 1, 1, '2050.00', '3500.00', 1, 1, 1, 1, '2021-08-30 16:59:08', 1, 1, 'img_04e6bfe967b3b9a5ddb2e5bb851d7317.jpg', '2864-20'),
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
(44, '45242559282', 'Navaja pico de Halcón', 'Navaja pico de Halcón con punta Redondeada fastback', 2, 1, 1, '114.00', '170.00', 1, 2, 1, 1, '2021-08-31 16:18:05', 1, 1, 'img_6dc1091a4f6c7ee7799acdf866b26353.jpg', '48-22-1526'),
(45, '4524255929', 'Navaja Plegable', 'Navaja Plegable Milwaukee con diseño Camuflado', 2, 1, 1, '130.00', '250.00', 1, 9, 1, 1, '2021-08-31 16:33:33', 1, 1, 'img_7809a60840fa3f3b355d3b09931c6c78.jpg', '48-22-1524'),
(46, '4524218003', 'Broca plana madera', 'Juego de Brocas Milwaukee planas universal 8 piezas', 2, 1, 1, '130.00', '300.00', 1, 9, 1, 1, '2021-08-31 16:56:15', 1, 1, 'img_01bca79fb645eefb99fa2d2ca4c4d2a9.jpg', '49-22-0175'),
(47, '45242534500', 'Navaja Fastback Asistida por Muelle', 'Navaja Fastback Asistida por Muelle Milwaukee con diseño Camuflado', 2, 1, 1, '186.00', '290.00', 1, 8, 1, 1, '2021-08-31 17:03:15', 1, 1, 'img_6089b158b8c838951eff3451c3da9204.jpg', '48-22-1535'),
(48, '45242555086', 'Juego de Cuchillas Utilitarias', 'Juego de Cuchillas Utilitarias Milwaukee 15 piezas', 2, 1, 1, '46.00', '90.00', 1, 8, 1, 1, '2021-08-31 17:08:04', 1, 1, 'img_6e550443f9ffa671145c00197e1383af.jpg', '48-22-1930'),
(49, '45242346820', 'Navaja para Ductos', 'Navaja para Ductos Milwaukee', 2, 1, 1, '126.00', '190.00', 1, 9, 1, 1, '2021-08-31 17:14:32', 1, 1, 'img_55726f4d26ac964683d06308ae31323f.jpg', '48-22-1920'),
(50, '45242573912', 'Navaja 6 en 1', 'Navaja Fastback Multiuso 6 en 1 Milwaukee', 2, 1, 1, '140.00', '200.00', 1, 10, 1, 1, '2021-08-31 17:19:24', 1, 1, 'img_d3f4177757334a989f0812c930f18f6e.jpg', '48-22-1505'),
(51, '4524230171', 'Destornillador de Demolición', 'Destornillador de Demolición de una sola pieza Milwaukee 2 piezas', 2, 1, 1, '94.00', '160.00', 1, 2, 1, 1, '2021-08-31 17:32:12', 1, 1, 'img_c4afd2f78a48e368cecf22b65aecaa6e.jpg', '48-22-2002'),
(52, '45242293780', 'Llaves para tuercas SAE', 'Juego de destornilladores para tuercas SAE (pulgadas) 4 piezas', 2, 1, 1, '149.00', '280.00', 1, 6, 1, 1, '2021-08-31 17:34:50', 1, 1, 'img_3053158fa8b9cdce18aaa9512e28ecf6.jpg', '48-22-2404'),
(53, '4524259270', 'Juego de Puntas 120 piezas', 'Juego de Puntas Milwaukee 120 piezas', 2, 1, 1, '250.00', '650.00', 1, 3, 1, 1, '2021-08-31 17:51:39', 1, 1, 'img_995067eea4da8d2b60bd48d1dfbb1edf.jpg', '48-32-4496'),
(54, '45242532674', 'Escuadra Milwaukee', 'Escuadra Milwaukee de 180mm', 2, 1, 1, '125.00', '190.00', 1, 15, 1, 1, '2021-09-01 09:51:24', 1, 1, 'img_5564fe94d2591221d990a143e903b555.jpg', 'MLSQ170'),
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
(77, '45645654646', 'Nivel Laser 180º 2 lineas', 'Nivel Laser 180º 2 lineas luz verde a bateria pila', 3, 1, 1, '1928.00', '2800.00', 1, 0, 1, 1, '2021-09-01 16:33:08', 1, 1, 'img_817869c55e228cd72bda228580e7bc4a.jpg', '3521-21'),
(78, '45242568314', 'Nivel laser 180º 2 lineas con plomada', 'Nivel laser 180º 2 lineas luz verde con plomada Milwaukee con batería recargable', 3, 1, 1, '2206.00', '3200.00', 1, 2, 1, 1, '2021-09-01 17:01:10', 1, 1, 'img_808d8d21e95f66c31eff8484b6c4acaa.jpg', '3522-21'),
(79, '78978987', 'Nivel Laser 360º 3 lineas', 'Nivel Laser 360º de 3 lineas verde Milwaukee con bateria recargable', 3, 1, 1, '3793.00', '5800.00', 1, 2, 1, 1, '2021-09-01 17:03:57', 1, 1, 'img_776ffce37c2419421194c78a0b9a1c34.jpg', '3632-21'),
(80, '045242511433', 'Juego de Puntas 52 piezas', 'Juego de Puntas Milwaukee 52 piezas', 2, 1, 1, '200.00', '430.00', 1, 1, 1, 1, '2021-09-02 16:54:00', 1, 1, 'img_6af94fb4a6774d910b9f90a8bdea97be.jpg', '48-32-4025'),
(81, '045242540389', 'Topes para Drywall 4 Piezas', 'Topes para Drywall 4 Piezas Milwaukee de 1\"', 2, 1, 1, '44.00', '90.00', 1, 1, 1, 1, '2021-09-03 14:47:22', 1, 1, 'img_7089c4cc63ce7d2db18ba36df9492fa7.jpg', '48-32-2101');

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
(1, '123456', 'Productos SA', 'Abel', 12345645, 'info@info.com', 'Ciudad', '2020-10-27 23:52:00', 1, 1);

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
(2, 'A2', 'Productos de tecnos', '2019-11-19 11:47:09', 1, 10),
(3, 'A3', 'Productos A3', '2020-05-19 01:27:04', 1, 10);

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
  MODIFY `idcategoria` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `categoria_producto`
--
ALTER TABLE `categoria_producto`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=83;

--
-- AUTO_INCREMENT de la tabla `cliente`
--
ALTER TABLE `cliente`
  MODIFY `idcliente` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=12;

--
-- AUTO_INCREMENT de la tabla `compra`
--
ALTER TABLE `compra`
  MODIFY `id_compra` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `contacto_pedido`
--
ALTER TABLE `contacto_pedido`
  MODIFY `id_contacto` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT de la tabla `detallefactura`
--
ALTER TABLE `detallefactura`
  MODIFY `correlativo` bigint(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=15;

--
-- AUTO_INCREMENT de la tabla `detalle_pedido`
--
ALTER TABLE `detalle_pedido`
  MODIFY `id_detalle` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

--
-- AUTO_INCREMENT de la tabla `detalle_temp`
--
ALTER TABLE `detalle_temp`
  MODIFY `correlativo` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=577;

--
-- AUTO_INCREMENT de la tabla `documento`
--
ALTER TABLE `documento`
  MODIFY `id_documento` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `entradas`
--
ALTER TABLE `entradas`
  MODIFY `correlativo` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `factura`
--
ALTER TABLE `factura`
  MODIFY `nofactura` bigint(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=14;

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
  MODIFY `idmarca` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT de la tabla `pedido`
--
ALTER TABLE `pedido`
  MODIFY `id_pedido` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT de la tabla `presentacion_producto`
--
ALTER TABLE `presentacion_producto`
  MODIFY `id_presentacion` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `producto`
--
ALTER TABLE `producto`
  MODIFY `codproducto` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=82;

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
  MODIFY `id_ubicacion` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `usuario`
--
ALTER TABLE `usuario`
  MODIFY `idusuario` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
