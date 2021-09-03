-- phpMyAdmin SQL Dump
-- version 5.1.1
-- https://www.phpmyadmin.net/
--
-- Servidor: 127.0.0.1
-- Tiempo de generación: 17-08-2021 a las 02:27:42
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
(2, 'Herramientas Manuales', 'De Todos Los Tipos', 0, 0, '2021-08-05 10:57:45', 1, 1);

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
(7, '852693', 'Henry Gonzalez', 703048952, 'henry@gmail.com', '', '', 'sacaba', '2021-08-09 08:51:37', 1, 1);

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
(1, '6405706018', 'Herramienta Eléctrica Bolivia ', 'Unipersonal', 'logo_empresa.jpg', '6759825', '67598258', 'nilton_bsb@hotmail.com', 'Av. capitan ustariz Esq. Zoilo Linares', 'IVA', 'Bolivianos', 'Bs.', 'America/Caracas', 'https://www.herramientaelectrica.com.bo', 'nilton_bsb@hotmail.com', 'nilton_bsb@hotmail.com', 'https://www.facebook.com/MilwaukeeToolBolivia', '', 'CI', 'NIT', ',', ',');

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
(3, 'Juan Pasten', 5673345, 'asd@hotmail.com', '3212354457', 'Semapa', 'heroinas');

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
(3, 3, 7, 1, '2500.00', 1),
(4, 4, 2, 1, '3500.00', 1);

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
(6, 3, 2, 1, '3500.00', 1);

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
(3, 1, 3, '2021-08-09', 1, 1, '2500.00', '0.00', 1, '2700.00', '2021-08-09 08:52:19', 2),
(4, 1, 4, '2021-08-12', 1, 1, '3500.00', '250.00', 1, '3300.00', '2021-08-12 10:01:06', 1);

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
(1, '2409AA-15028D-D4D5T5-ER458F-FD45S8', '123-250-01', '2020-10-28', '2022-12-31', 1, 2000, 9, 1, '2020-10-28 00:02:32', 1);

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
(2, 12, 'IMPUESTO 12%', '2020-10-27 23:57:45', 0, 1);

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
(1, 'Milwaukee', 'Herramientas Eléctricas Y Manuales', '2020-10-27 23:54:05', 1, 1);

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
(3, '2021-08-16', 3, 1, '8800.00', 1);

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
(2, '2975', 'Jego de Taladros Milwaukee M18', 'Juego de Taladros Milwaukee con dos baterias , cargador y maletin', 1, 1, 1, '2500.00', '3500.00', 1, 29, 1, 1, '2021-08-05 11:02:01', 2, 1, 'img_producto.png', '2997-22'),
(16, '89990', 'Taladro Percutor M18', 'Taladro Percutor con dos baterias de 5 Amp, cargafor 220v y maletin', 1, 1, 1, '1950.00', '2650.00', 1, 10, 1, 1, '2021-08-10 16:37:14', 1, 1, 'img_producto.png', '2804-22');

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
  MODIFY `idcategoria` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT de la tabla `categoria_producto`
--
ALTER TABLE `categoria_producto`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=83;

--
-- AUTO_INCREMENT de la tabla `cliente`
--
ALTER TABLE `cliente`
  MODIFY `idcliente` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT de la tabla `compra`
--
ALTER TABLE `compra`
  MODIFY `id_compra` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `contacto_pedido`
--
ALTER TABLE `contacto_pedido`
  MODIFY `id_contacto` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `detallefactura`
--
ALTER TABLE `detallefactura`
  MODIFY `correlativo` bigint(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT de la tabla `detalle_pedido`
--
ALTER TABLE `detalle_pedido`
  MODIFY `id_detalle` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT de la tabla `detalle_temp`
--
ALTER TABLE `detalle_temp`
  MODIFY `correlativo` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=553;

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
  MODIFY `nofactura` bigint(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

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
  MODIFY `idmarca` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `pedido`
--
ALTER TABLE `pedido`
  MODIFY `id_pedido` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `presentacion_producto`
--
ALTER TABLE `presentacion_producto`
  MODIFY `id_presentacion` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `producto`
--
ALTER TABLE `producto`
  MODIFY `codproducto` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=18;

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
