// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Ownable} from "lib/solady/src/auth/Ownable.sol";
import {Test, console2} from "lib/forge-std/src/Test.sol";

import {Ashurbanipal} from "../src/Ashurbanipal.sol";
import {
    Blacklisted,
    CannotDoubleConfirmPassage,
    CannotReassignOwnMetadata,
    ContentTooLarge,
    EmptyTitle,
    InvalidPassageId,
    MetadataTooLarge,
    Nabu,
    NoChangeInMetadata,
    NoPass,
    NoPassageContent,
    NotWorkAdmin,
    ONE_DAY,
    PassCooldown,
    PassageAlreadyFinalized,
    ReadablePassage,
    SEVEN_DAYS,
    THIRTY_DAYS,
    TooLate,
    TooSoonToAssignContent,
    TooSoonToAssignMetadata,
    TooSoonToConfirmContent,
    Work,
    ZeroPassagesCount
} from "../src/Nabu.sol";

contract NabuTest is Ownable, Test {
    Ashurbanipal private _ashurbanipal;
    Nabu private _nabu;

    address alice = makeAddr("Alice");
    address bob = makeAddr("Bob");
    address charlie = makeAddr("Charlie");
    address dave = makeAddr("Dave");
    address frank = makeAddr("Frank");
    address mallory = makeAddr("Mallory");

    modifier prank(address addr) {
        vm.startPrank(addr);
        _;
        vm.stopPrank();
    }

    function setUp() public {
        vm.roll(0);
        _nabu = new Nabu();
        address nabuAddress = address(_nabu);
        _ashurbanipal = new Ashurbanipal(nabuAddress);
        _nabu.updateAshurbanipal(address(_ashurbanipal));
    }

    bytes passageOne = bytes(
        unicode"En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero, adarga antigua, rocín flaco y galgo corredor. Una olla de algo más vaca que carnero, salpicón las más noches, duelos y quebrantos los sábados, lantejas los viernes, algún palomino de añadidura los domingos, consumían las tres partes de su hacienda. El resto della concluían sayo de velarte, calzas de velludo para las fiestas, con sus pantuflos de lo mesmo, y los días de entresemana se honraba con su vellorí de lo más fino. Tenía en su casa una ama que pasaba de los cuarenta, y una sobrina que no llegaba a los veinte, y un mozo de campo y plaza, que así ensillaba el rocín como tomaba la podadera. Frisaba la edad de nuestro hidalgo con los cincuenta años; era de complexión recia, seco de carnes, enjuto de rostro, gran madrugador y amigo de la caza. Quieren decir que tenía el sobrenombre de Quijada, o Quesada, que en esto hay alguna diferencia en los autores que deste caso escriben; aunque, por conjeturas verosímiles, se deja entender que se llamaba Quejana. Pero esto importa poco a nuestro cuento; basta que en la narración dél no se salga un punto de la verdad."
    );

    bytes passageOneMalicious = bytes(unicode"¡Soy muy malo y quiero destruir el patrimonio literario de España!");

    bytes passageOneMetadata = bytes("Chapter 1, Verse 1");
    bytes passageTwoMetadata = bytes("Chapter 1, Verse 2");

    bytes passageTooLong = bytes(
        unicode"En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero, adarga antigua, rocín flaco y galgo corredor. Una olla de algo más vaca que carnero, salpicón las más noches, duelos y quebrantos los sábados, lantejas los viernes, algún palomino de añadidura los domingos, consumían las tres partes de su hacienda. El resto della concluían sayo de velarte, calzas de velludo para las fiestas, con sus pantuflos de lo mesmo, y los días de entresemana se honraba con su vellorí de lo más fino. Tenía en su casa una ama que pasaba de los cuarenta, y una sobrina que no llegaba a los veinte, y un mozo de campo y plaza, que así ensillaba el rocín como tomaba la podadera. Frisaba la edad de nuestro hidalgo con los cincuenta años; era de complexión recia, seco de carnes, enjuto de rostro, gran madrugador y amigo de la caza. Quieren decir que tenía el sobrenombre de Quijada, o Quesada, que en esto hay alguna diferencia en los autores que deste caso escriben; aunque, por conjeturas verosímiles, se deja entender que se llamaba Quejana. Pero esto importa poco a nuestro cuento; basta que en la narración dél no se salga un punto de la verdad. En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero, adarga antigua, rocín flaco y galgo corredor. Una olla de algo más vaca que carnero, salpicón las más noches, duelos y quebrantos los sábados, lantejas los viernes, algún palomino de añadidura los domingos, consumían las tres partes de su hacienda. El resto della concluían sayo de velarte, calzas de velludo para las fiestas, con sus pantuflos de lo mesmo, y los días de entresemana se honraba con su vellorí de lo más fino. Tenía en su casa una ama que pasaba de los cuarenta, y una sobrina que no llegaba a los veinte, y un mozo de campo y plaza, que así ensillaba el rocín como tomaba la podadera. Frisaba la edad de nuestro hidalgo con los cincuenta años; era de complexión recia, seco de carnes, enjuto de rostro, gran madrugador y amigo de la caza. Quieren decir que tenía el sobrenombre de Quijada, o Quesada, que en esto hay alguna diferencia en los autores que deste caso escriben; aunque, por conjeturas verosímiles, se deja entender que se llamaba Quejana. Pero esto importa poco a nuestro cuento; basta que en la narración dél no se salga un punto de la verdad. En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero, adarga antigua, rocín flaco y galgo corredor. Una olla de algo más vaca que carnero, salpicón las más noches, duelos y quebrantos los sábados, lantejas los viernes, algún palomino de añadidura los domingos, consumían las tres partes de su hacienda. El resto della concluían sayo de velarte, calzas de velludo para las fiestas, con sus pantuflos de lo mesmo, y los días de entresemana se honraba con su vellorí de lo más fino. Tenía en su casa una ama que pasaba de los cuarenta, y una sobrina que no llegaba a los veinte, y un mozo de campo y plaza, que así ensillaba el rocín como tomaba la podadera. Frisaba la edad de nuestro hidalgo con los cincuenta años; era de complexión recia, seco de carnes, enjuto de rostro, gran madrugador y amigo de la caza. Quieren decir que tenía el sobrenombre de Quijada, o Quesada, que en esto hay alguna diferencia en los autores que deste caso escriben; aunque, por conjeturas verosímiles, se deja entender que se llamaba Quejana. Pero esto importa poco a nuestro cuento; basta que en la narración dél no se salga un punto de la verdad. En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero, adarga antigua, rocín flaco y galgo corredor. Una olla de algo más vaca que carnero, salpicón las más noches, duelos y quebrantos los sábados, lantejas los viernes, algún palomino de añadidura los domingos, consumían las tres partes de su hacienda. El resto della concluían sayo de velarte, calzas de velludo para las fiestas, con sus pantuflos de lo mesmo, y los días de entresemana se honraba con su vellorí de lo más fino. Tenía en su casa una ama que pasaba de los cuarenta, y una sobrina que no llegaba a los veinte, y un mozo de campo y plaza, que así ensillaba el rocín como tomaba la podadera. Frisaba la edad de nuestro hidalgo con los cincuenta años; era de complexión recia, seco de carnes, enjuto de rostro, gran madrugador y amigo de la caza. Quieren decir que tenía el sobrenombre de Quijada, o Quesada, que en esto hay alguna diferencia en los autores que deste caso escriben; aunque, por conjeturas verosímiles, se deja entender que se llamaba Quejana. Pero esto importa poco a nuestro cuento; basta que en la narración dél no se salga un punto de la verdad. En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero, adarga antigua, rocín flaco y galgo corredor. Una olla de algo más vaca que carnero, salpicón las más noches, duelos y quebrantos los sábados, lantejas los viernes, algún palomino de añadidura los domingos, consumían las tres partes de su hacienda. El resto della concluían sayo de velarte, calzas de velludo para las fiestas, con sus pantuflos de lo mesmo, y los días de entresemana se honraba con su vellorí de lo más fino. Tenía en su casa una ama que pasaba de los cuarenta, y una sobrina que no llegaba a los veinte, y un mozo de campo y plaza, que así ensillaba el rocín como tomaba la podadera. Frisaba la edad de nuestro hidalgo con los cincuenta años; era de complexión recia, seco de carnes, enjuto de rostro, gran madrugador y amigo de la caza. Quieren decir que tenía el sobrenombre de Quijada, o Quesada, que en esto hay alguna diferencia en los autores que deste caso escriben; aunque, por conjeturas verosímiles, se deja entender que se llamaba Quejana. Pero esto importa poco a nuestro cuento; basta que en la narración dél no se salga un punto de la verdad. En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero, adarga antigua, rocín flaco y galgo corredor. Una olla de algo más vaca que carnero, salpicón las más noches, duelos y quebrantos los sábados, lantejas los viernes, algún palomino de añadidura los domingos, consumían las tres partes de su hacienda. El resto della concluían sayo de velarte, calzas de velludo para las fiestas, con sus pantuflos de lo mesmo, y los días de entresemana se honraba con su vellorí de lo más fino. Tenía en su casa una ama que pasaba de los cuarenta, y una sobrina que no llegaba a los veinte, y un mozo de campo y plaza, que así ensillaba el rocín como tomaba la podadera. Frisaba la edad de nuestro hidalgo con los cincuenta años; era de complexión recia, seco de carnes, enjuto de rostro, gran madrugador y amigo de la caza. Quieren decir que tenía el sobrenombre de Quijada, o Quesada, que en esto hay alguna diferencia en los autores que deste caso escriben; aunque, por conjeturas verosímiles, se deja entender que se llamaba Quejana. Pero esto importa poco a nuestro cuento; basta que en la narración dél no se salga un punto de la verdad. En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero, adarga antigua, rocín flaco y galgo corredor. Una olla de algo más vaca que carnero, salpicón las más noches, duelos y quebrantos los sábados, lantejas los viernes, algún palomino de añadidura los domingos, consumían las tres partes de su hacienda. El resto della concluían sayo de velarte, calzas de velludo para las fiestas, con sus pantuflos de lo mesmo, y los días de entresemana se honraba con su vellorí de lo más fino. Tenía en su casa una ama que pasaba de los cuarenta, y una sobrina que no llegaba a los veinte, y un mozo de campo y plaza, que así ensillaba el rocín como tomaba la podadera. Frisaba la edad de nuestro hidalgo con los cincuenta años; era de complexión recia, seco de carnes, enjuto de rostro, gran madrugador y amigo de la caza. Quieren decir que tenía el sobrenombre de Quijada, o Quesada, que en esto hay alguna diferencia en los autores que deste caso escriben; aunque, por conjeturas verosímiles, se deja entender que se llamaba Quejana. Pero esto importa poco a nuestro cuento; basta que en la narración dél no se salga un punto de la verdad. En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero, adarga antigua, rocín flaco y galgo corredor. Una olla de algo más vaca que carnero, salpicón las más noches, duelos y quebrantos los sábados, lantejas los viernes, algún palomino de añadidura los domingos, consumían las tres partes de su hacienda. El resto della concluían sayo de velarte, calzas de velludo para las fiestas, con sus pantuflos de lo mesmo, y los días de entresemana se honraba con su vellorí de lo más fino. Tenía en su casa una ama que pasaba de los cuarenta, y una sobrina que no llegaba a los veinte, y un mozo de campo y plaza, que así ensillaba el rocín como tomaba la podadera. Frisaba la edad de nuestro hidalgo con los cincuenta años; era de complexión recia, seco de carnes, enjuto de rostro, gran madrugador y amigo de la caza. Quieren decir que tenía el sobrenombre de Quijada, o Quesada, que en esto hay alguna diferencia en los autores que deste caso escriben; aunque, por conjeturas verosímiles, se deja entender que se llamaba Quejana. Pero esto importa poco a nuestro cuento; basta que en la narración dél no se salga un punto de la verdad. En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero, adarga antigua, rocín flaco y galgo corredor. Una olla de algo más vaca que carnero, salpicón las más noches, duelos y quebrantos los sábados, lantejas los viernes, algún palomino de añadidura los domingos, consumían las tres partes de su hacienda. El resto della concluían sayo de velarte, calzas de velludo para las fiestas, con sus pantuflos de lo mesmo, y los días de entresemana se honraba con su vellorí de lo más fino. Tenía en su casa una ama que pasaba de los cuarenta, y una sobrina que no llegaba a los veinte, y un mozo de campo y plaza, que así ensillaba el rocín como tomaba la podadera. Frisaba la edad de nuestro hidalgo con los cincuenta años; era de complexión recia, seco de carnes, enjuto de rostro, gran madrugador y amigo de la caza. Quieren decir que tenía el sobrenombre de Quijada, o Quesada, que en esto hay alguna diferencia en los autores que deste caso escriben; aunque, por conjeturas verosímiles, se deja entender que se llamaba Quejana. Pero esto importa poco a nuestro cuento; basta que en la narración dél no se salga un punto de la verdad. En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero, adarga antigua, rocín flaco y galgo corredor. Una olla de algo más vaca que carnero, salpicón las más noches, duelos y quebrantos los sábados, lantejas los viernes, algún palomino de añadidura los domingos, consumían las tres partes de su hacienda. El resto della concluían sayo de velarte, calzas de velludo para las fiestas, con sus pantuflos de lo mesmo, y los días de entresemana se honraba con su vellorí de lo más fino. Tenía en su casa una ama que pasaba de los cuarenta, y una sobrina que no llegaba a los veinte, y un mozo de campo y plaza, que así ensillaba el rocín como tomaba la podadera. Frisaba la edad de nuestro hidalgo con los cincuenta años; era de complexión recia, seco de carnes, enjuto de rostro, gran madrugador y amigo de la caza. Quieren decir que tenía el sobrenombre de Quijada, o Quesada, que en esto hay alguna diferencia en los autores que deste caso escriben; aunque, por conjeturas verosímiles, se deja entender que se llamaba Quejana. Pero esto importa poco a nuestro cuento; basta que en la narración dél no se salga un punto de la verdad. En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero, adarga antigua, rocín flaco y galgo corredor. Una olla de algo más vaca que carnero, salpicón las más noches, duelos y quebrantos los sábados, lantejas los viernes, algún palomino de añadidura los domingos, consumían las tres partes de su hacienda. El resto della concluían sayo de velarte, calzas de velludo para las fiestas, con sus pantuflos de lo mesmo, y los días de entresemana se honraba con su vellorí de lo más fino. Tenía en su casa una ama que pasaba de los cuarenta, y una sobrina que no llegaba a los veinte, y un mozo de campo y plaza, que así ensillaba el rocín como tomaba la podadera. Frisaba la edad de nuestro hidalgo con los cincuenta años; era de complexión recia, seco de carnes, enjuto de rostro, gran madrugador y amigo de la caza. Quieren decir que tenía el sobrenombre de Quijada, o Quesada, que en esto hay alguna diferencia en los autores que deste caso escriben; aunque, por conjeturas verosímiles, se deja entender que se llamaba Quejana. Pero esto importa poco a nuestro cuento; basta que en la narración dél no se salga un punto de la verdad. En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero, adarga antigua, rocín flaco y galgo corredor. Una olla de algo más vaca que carnero, salpicón las más noches, duelos y quebrantos los sábados, lantejas los viernes, algún palomino de añadidura los domingos, consumían las tres partes de su hacienda. El resto della concluían sayo de velarte, calzas de velludo para las fiestas, con sus pantuflos de lo mesmo, y los días de entresemana se honraba con su vellorí de lo más fino. Tenía en su casa una ama que pasaba de los cuarenta, y una sobrina que no llegaba a los veinte, y un mozo de campo y plaza, que así ensillaba el rocín como tomaba la podadera. Frisaba la edad de nuestro hidalgo con los cincuenta años; era de complexión recia, seco de carnes, enjuto de rostro, gran madrugador y amigo de la caza. Quieren decir que tenía el sobrenombre de Quijada, o Quesada, que en esto hay alguna diferencia en los autores que deste caso escriben; aunque, por conjeturas verosímiles, se deja entender que se llamaba Quejana. Pero esto importa poco a nuestro cuento; basta que en la narración dél no se salga un punto de la verdad. En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero, adarga antigua, rocín flaco y galgo corredor. Una olla de algo más vaca que carnero, salpicón las más noches, duelos y quebrantos los sábados, lantejas los viernes, algún palomino de añadidura los domingos, consumían las tres partes de su hacienda. El resto della concluían sayo de velarte, calzas de velludo para las fiestas, con sus pantuflos de lo mesmo, y los días de entresemana se honraba con su vellorí de lo más fino. Tenía en su casa una ama que pasaba de los cuarenta, y una sobrina que no llegaba a los veinte, y un mozo de campo y plaza, que así ensillaba el rocín como tomaba la podadera. Frisaba la edad de nuestro hidalgo con los cincuenta años; era de complexión recia, seco de carnes, enjuto de rostro, gran madrugador y amigo de la caza. Quieren decir que tenía el sobrenombre de Quijada, o Quesada, que en esto hay alguna diferencia en los autores que deste caso escriben; aunque, por conjeturas verosímiles, se deja entender que se llamaba Quejana. Pero esto importa poco a nuestro cuento; basta que en la narración dél no se salga un punto de la verdad. En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero, adarga antigua, rocín flaco y galgo corredor. Una olla de algo más vaca que carnero, salpicón las más noches, duelos y quebrantos los sábados, lantejas los viernes, algún palomino de añadidura los domingos, consumían las tres partes de su hacienda. El resto della concluían sayo de velarte, calzas de velludo para las fiestas, con sus pantuflos de lo mesmo, y los días de entresemana se honraba con su vellorí de lo más fino. Tenía en su casa una ama que pasaba de los cuarenta, y una sobrina que no llegaba a los veinte, y un mozo de campo y plaza, que así ensillaba el rocín como tomaba la podadera. Frisaba la edad de nuestro hidalgo con los cincuenta años; era de complexión recia, seco de carnes, enjuto de rostro, gran madrugador y amigo de la caza. Quieren decir que tenía el sobrenombre de Quijada, o Quesada, que en esto hay alguna diferencia en los autores que deste caso escriben; aunque, por conjeturas verosímiles, se deja entender que se llamaba Quejana. Pero esto importa poco a nuestro cuento; basta que en la narración dél no se salga un punto de la verdad. En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero, adarga antigua, rocín flaco y galgo corredor. Una olla de algo más vaca que carnero, salpicón las más noches, duelos y quebrantos los sábados, lantejas los viernes, algún palomino de añadidura los domingos, consumían las tres partes de su hacienda. El resto della concluían sayo de velarte, calzas de velludo para las fiestas, con sus pantuflos de lo mesmo, y los días de entresemana se honraba con su vellorí de lo más fino. Tenía en su casa una ama que pasaba de los cuarenta, y una sobrina que no llegaba a los veinte, y un mozo de campo y plaza, que así ensillaba el rocín como tomaba la podadera. Frisaba la edad de nuestro hidalgo con los cincuenta años; era de complexión recia, seco de carnes, enjuto de rostro, gran madrugador y amigo de la caza. Quieren decir que tenía el sobrenombre de Quijada, o Quesada, que en esto hay alguna diferencia en los autores que deste caso escriben; aunque, por conjeturas verosímiles, se deja entender que se llamaba Quejana. Pero esto importa poco a nuestro cuento; basta que en la narración dél no se salga un punto de la verdad. En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero, adarga antigua, rocín flaco y galgo corredor. Una olla de algo más vaca que carnero, salpicón las más noches, duelos y quebrantos los sábados, lantejas los viernes, algún palomino de añadidura los domingos, consumían las tres partes de su hacienda. El resto della concluían sayo de velarte, calzas de velludo para las fiestas, con sus pantuflos de lo mesmo, y los días de entresemana se honraba con su vellorí de lo más fino. Tenía en su casa una ama que pasaba de los cuarenta, y una sobrina que no llegaba a los veinte, y un mozo de campo y plaza, que así ensillaba el rocín como tomaba la podadera. Frisaba la edad de nuestro hidalgo con los cincuenta años; era de complexión recia, seco de carnes, enjuto de rostro, gran madrugador y amigo de la caza. Quieren decir que tenía el sobrenombre de Quijada, o Quesada, que en esto hay alguna diferencia en los autores que deste caso escriben; aunque, por conjeturas verosímiles, se deja entender que se llamaba Quejana. Pero esto importa poco a nuestro cuento; basta que en la narración dél no se salga un punto de la verdad. En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero, adarga antigua, rocín flaco y galgo corredor. Una olla de algo más vaca que carnero, salpicón las más noches, duelos y quebrantos los sábados, lantejas los viernes, algún palomino de añadidura los domingos, consumían las tres partes de su hacienda. El resto della concluían sayo de velarte, calzas de velludo para las fiestas, con sus pantuflos de lo mesmo, y los días de entresemana se honraba con su vellorí de lo más fino. Tenía en su casa una ama que pasaba de los cuarenta, y una sobrina que no llegaba a los veinte, y un mozo de campo y plaza, que así ensillaba el rocín como tomaba la podadera. Frisaba la edad de nuestro hidalgo con los cincuenta años; era de complexión recia, seco de carnes, enjuto de rostro, gran madrugador y amigo de la caza. Quieren decir que tenía el sobrenombre de Quijada, o Quesada, que en esto hay alguna diferencia en los autores que deste caso escriben; aunque, por conjeturas verosímiles, se deja entender que se llamaba Quejana. Pero esto importa poco a nuestro cuento; basta que en la narración dél no se salga un punto de la verdad. En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero, adarga antigua, rocín flaco y galgo corredor. Una olla de algo más vaca que carnero, salpicón las más noches, duelos y quebrantos los sábados, lantejas los viernes, algún palomino de añadidura los domingos, consumían las tres partes de su hacienda. El resto della concluían sayo de velarte, calzas de velludo para las fiestas, con sus pantuflos de lo mesmo, y los días de entresemana se honraba con su vellorí de lo más fino. Tenía en su casa una ama que pasaba de los cuarenta, y una sobrina que no llegaba a los veinte, y un mozo de campo y plaza, que así ensillaba el rocín como tomaba la podadera. Frisaba la edad de nuestro hidalgo con los cincuenta años; era de complexión recia, seco de carnes, enjuto de rostro, gran madrugador y amigo de la caza. Quieren decir que tenía el sobrenombre de Quijada, o Quesada, que en esto hay alguna diferencia en los autores que deste caso escriben; aunque, por conjeturas verosímiles, se deja entender que se llamaba Quejana. Pero esto importa poco a nuestro cuento; basta que en la narración dél no se salga un punto de la verdad. En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero, adarga antigua, rocín flaco y galgo corredor. Una olla de algo más vaca que carnero, salpicón las más noches, duelos y quebrantos los sábados, lantejas los viernes, algún palomino de añadidura los domingos, consumían las tres partes de su hacienda. El resto della concluían sayo de velarte, calzas de velludo para las fiestas, con sus pantuflos de lo mesmo, y los días de entresemana se honraba con su vellorí de lo más fino. Tenía en su casa una ama que pasaba de los cuarenta, y una sobrina que no llegaba a los veinte, y un mozo de campo y plaza, que así ensillaba el rocín como tomaba la podadera. Frisaba la edad de nuestro hidalgo con los cincuenta años; era de complexión recia, seco de carnes, enjuto de rostro, gran madrugador y amigo de la caza. Quieren decir que tenía el sobrenombre de Quijada, o Quesada, que en esto hay alguna diferencia en los autores que deste caso escriben; aunque, por conjeturas verosímiles, se deja entender que se llamaba Quejana. Pero esto importa poco a nuestro cuento; basta que en la narración dél no se salga un punto de la verdad. En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero, adarga antigua, rocín flaco y galgo corredor. Una olla de algo más vaca que carnero, salpicón las más noches, duelos y quebrantos los sábados, lantejas los viernes, algún palomino de añadidura los domingos, consumían las tres partes de su hacienda. El resto della concluían sayo de velarte, calzas de velludo para las fiestas, con sus pantuflos de lo mesmo, y los días de entresemana se honraba con su vellorí de lo más fino. Tenía en su casa una ama que pasaba de los cuarenta, y una sobrina que no llegaba a los veinte, y un mozo de campo y plaza, que así ensillaba el rocín como tomaba la podadera. Frisaba la edad de nuestro hidalgo con los cincuenta años; era de complexión recia, seco de carnes, enjuto de rostro, gran madrugador y amigo de la caza. Quieren decir que tenía el sobrenombre de Quijada, o Quesada, que en esto hay alguna diferencia en los autores que deste caso escriben; aunque, por conjeturas verosímiles, se deja entender que se llamaba Quejana. Pero esto importa poco a nuestro cuento; basta que en la narración dél no se salga un punto de la verdad. En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero, adarga antigua, rocín flaco y galgo corredor. Una olla de algo más vaca que carnero, salpicón las más noches, duelos y quebrantos los sábados, lantejas los viernes, algún palomino de añadidura los domingos, consumían las tres partes de su hacienda. El resto della concluían sayo de velarte, calzas de velludo para las fiestas, con sus pantuflos de lo mesmo, y los días de entresemana se honraba con su vellorí de lo más fino. Tenía en su casa una ama que pasaba de los cuarenta, y una sobrina que no llegaba a los veinte, y un mozo de campo y plaza, que así ensillaba el rocín como tomaba la podadera. Frisaba la edad de nuestro hidalgo con los cincuenta años; era de complexión recia, seco de carnes, enjuto de rostro, gran madrugador y amigo de la caza. Quieren decir que tenía el sobrenombre de Quijada, o Quesada, que en esto hay alguna diferencia en los autores que deste caso escriben; aunque, por conjeturas verosímiles, se deja entender que se llamaba Quejana. Pero esto importa poco a nuestro cuento; basta que en la narración dél no se salga un punto de la verdad. En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero, adarga antigua, rocín flaco y galgo corredor. Una olla de algo más vaca que carnero, salpicón las más noches, duelos y quebrantos los sábados, lantejas los viernes, algún palomino de añadidura los domingos, consumían las tres partes de su hacienda. El resto della concluían sayo de velarte, calzas de velludo para las fiestas, con sus pantuflos de lo mesmo, y los días de entresemana se honraba con su vellorí de lo más fino. Tenía en su casa una ama que pasaba de los cuarenta, y una sobrina que no llegaba a los veinte, y un mozo de campo y plaza, que así ensillaba el rocín como tomaba la podadera. Frisaba la edad de nuestro hidalgo con los cincuenta años; era de complexión recia, seco de carnes, enjuto de rostro, gran madrugador y amigo de la caza. Quieren decir que tenía el sobrenombre de Quijada, o Quesada, que en esto hay alguna diferencia en los autores que deste caso escriben; aunque, por conjeturas verosímiles, se deja entender que se llamaba Quejana. Pero esto importa poco a nuestro cuento; basta que en la narración dél no se salga un punto de la verdad."
    );

    function createWork(address to) private returns (uint256) {
        uint256 workId = _nabu.createWork(
            "Miguel de Cervantes",
            "Original title: El ingenioso hidalgo don Quijote de la Mancha",
            "Don Quijote",
            1_000_000,
            "https://foo.bar/{id}.json",
            10_000,
            to
        );

        return workId;
    }

    function distributePasses(uint256 workId) private {
        _ashurbanipal.safeTransferFrom(alice, bob, workId, 1_000, "");
        _ashurbanipal.safeTransferFrom(alice, charlie, workId, 2_000, "");
        _ashurbanipal.safeTransferFrom(alice, dave, workId, 500, "");
        _ashurbanipal.safeTransferFrom(alice, mallory, workId, 666, "");
    }

    function createWorkAndDistributePassesAsAlice() private prank(alice) returns (uint256) {
        uint256 workId = createWork(alice);
        distributePasses(workId);
        return workId;
    }

    function assertPassage(
        ReadablePassage memory actual,
        uint256 expectedAt,
        address expectedByZero,
        address expectedByOne,
        address expectedByTwo,
        bytes memory expectedContent,
        address expectedMetadataBy,
        uint256 expectedMetadataAt,
        bytes memory expectedMetadata
    ) internal {
        assertEq(actual.at, expectedAt, "ReadablePassage.at mismatch");
        assertEq(actual.byZero, expectedByZero, "ReadablePassage.byZero mismatch");
        assertEq(actual.byOne, expectedByOne, "ReadablePassage.byOne mismatch");
        assertEq(actual.byTwo, expectedByTwo, "ReadablePassage.byTwo mismatch");

        assertEq(
            keccak256(actual.readableContent), keccak256(expectedContent), "ReadablePassage.readableContent mismatch"
        );

        assertEq(actual.metadataBy, expectedMetadataBy, "ReadablePassage.metadataBy mismatch");
        assertEq(actual.metadataAt, expectedMetadataAt, "ReadablePassage.metadataAt mismatch");

        assertEq(
            keccak256(actual.readableMetadata), keccak256(expectedMetadata), "ReadablePassage.readableMetadata mismatch"
        );
    }

    function test_createWork() public {
        vm.prank(alice);
        uint256 workId = createWork(alice);
        assertEq(workId, 1, "Work ID mismatch");

        Work memory work = _nabu.getWork(workId);

        string memory author = work.author;
        string memory expectedAuthor = "Miguel de Cervantes";
        assertEq(author, expectedAuthor, "Author mismatch");

        string memory metadata = work.metadata;
        string memory expectedMetadata = "Original title: El ingenioso hidalgo don Quijote de la Mancha";
        assertEq(metadata, expectedMetadata, "Metadata mismatch");

        string memory title = _nabu.getWork(workId).title;
        string memory expectedTitle = "Don Quijote";
        assertEq(title, expectedTitle, "Title mismatch");

        uint256 totalPassagesCount = work.totalPassagesCount;
        uint256 expectedTotalPassagesCount = 1_000_000;
        assertEq(totalPassagesCount, expectedTotalPassagesCount, "Total passages count mismatch");

        string memory uri = _ashurbanipal.uri(workId);
        string memory expectedUri = "https://foo.bar/{id}.json";
        assertEq(uri, expectedUri, "URI mismatch");

        uint256 alicePassBalance = _ashurbanipal.balanceOf(alice, workId);
        uint256 expectedAlicePassBalance = 10_000;
        assertEq(alicePassBalance, expectedAlicePassBalance, "Alice pass balance mismatch");
    }

    function test_createWork_secondWork() public {
        vm.prank(alice);
        createWork(alice);

        vm.prank(bob);
        uint256 workId = _nabu.createWork(
            "William Shakespeare",
            "Arbitrary informative metadata",
            "Hamlet",
            20_000,
            "https://baz.qux/{id}.json",
            50,
            bob
        );
        assertEq(workId, 2, "Work ID mismatch");

        Work memory work = _nabu.getWork(workId);

        string memory author = work.author;
        string memory expectedAuthor = "William Shakespeare";
        assertEq(author, expectedAuthor, "Author mismatch");

        string memory metadata = work.metadata;
        string memory expectedMetadata = "Arbitrary informative metadata";
        assertEq(metadata, expectedMetadata, "Metadata mismatch");

        string memory title = _nabu.getWork(workId).title;
        string memory expectedTitle = "Hamlet";
        assertEq(title, expectedTitle, "Title mismatch");

        uint256 totalPassagesCount = work.totalPassagesCount;
        uint256 expectedTotalPassagesCount = 20_000;
        assertEq(totalPassagesCount, expectedTotalPassagesCount, "Total passages count mismatch");

        string memory uri = _ashurbanipal.uri(workId);
        string memory expectedUri = "https://baz.qux/{id}.json";
        assertEq(uri, expectedUri, "URI mismatch");

        uint256 bobPassBalance = _ashurbanipal.balanceOf(bob, workId);
        uint256 expectedBobPassBalance = 50;
        assertEq(bobPassBalance, expectedBobPassBalance, "Bob pass balance mismatch");
    }

    function test_distributePassesUtil() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        uint256 endingAlicePassBalance = _ashurbanipal.balanceOf(alice, workId);
        uint256 expectedEndingAlicePassBalance = 5_834;
        assertEq(endingAlicePassBalance, expectedEndingAlicePassBalance, "Ending Alice pass balance mismatch");

        uint256 bobPassBalance = _ashurbanipal.balanceOf(bob, workId);
        uint256 expectedBobPassBalance = 1_000;
        assertEq(bobPassBalance, expectedBobPassBalance, "Bob pass balance mismatch");

        uint256 charliePassBalance = _ashurbanipal.balanceOf(charlie, workId);
        uint256 expectedCharliePassBalance = 2_000;
        assertEq(charliePassBalance, expectedCharliePassBalance, "Charlie pass balance mismatch");

        uint256 davePassBalance = _ashurbanipal.balanceOf(dave, workId);
        uint256 expectedDavePassBalance = 500;
        assertEq(davePassBalance, expectedDavePassBalance, "Dave pass balance mismatch");

        uint256 malloryPassBalance = _ashurbanipal.balanceOf(mallory, workId);
        uint256 expectedMalloryPassBalance = 666;
        assertEq(malloryPassBalance, expectedMalloryPassBalance, "Mallory pass balance mismatch");
    }

    function test_assignPassageContent() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        _nabu.assignPassageContent(workId, 1, passageOne);

        ReadablePassage memory passage = _nabu.getPassage(workId, 1);

        assertPassage({
            actual: passage,
            expectedAt: 0,
            expectedByZero: bob,
            expectedByOne: address(0),
            expectedByTwo: address(0),
            expectedContent: passageOne,
            expectedMetadataBy: address(0),
            expectedMetadataAt: 0,
            expectedMetadata: ""
        });
    }

    function test_assignPassageContent_reverts_whenPassageIdIsInvalid() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(InvalidPassageId.selector));
        _nabu.assignPassageContent(workId, 1_000_001, passageOne);
    }

    function test_assignPassageContent_reverts_whenCallerIsBlacklisted() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(alice);
        _nabu.updateBlacklist(workId, bob, true);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Blacklisted.selector));
        _nabu.assignPassageContent(workId, 1, passageOne);
    }

    function test_confirmPassage_reverts_whenCallerHasNoPass() public {
        vm.startPrank(alice, alice);
        uint256 workId = createWork(alice);
        _nabu.assignPassageContent(workId, 1, passageOne);
        vm.stopPrank();

        vm.roll(ONE_DAY);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(NoPass.selector));
        _nabu.confirmPassageContent(workId, 1);
    }

    function test_assignPassageContent_reverts_whenCallerHasNoPass() public {
        vm.prank(alice);
        uint256 workId = createWork(alice);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(NoPass.selector));
        _nabu.assignPassageContent(workId, 1, passageOne);
    }

    function test_confirmPassage_manuallyConfirmOnce() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        _nabu.assignPassageContent(workId, 1, passageOne);

        vm.roll(ONE_DAY);
        vm.prank(charlie);
        _nabu.assignPassageContent(workId, 1, passageOne);

        ReadablePassage memory passage = _nabu.getPassage(workId, 1);

        assertPassage({
            actual: passage,
            expectedAt: ONE_DAY,
            expectedByZero: bob,
            expectedByOne: charlie,
            expectedByTwo: address(0),
            expectedContent: passageOne,
            expectedMetadataBy: address(0),
            expectedMetadataAt: 0,
            expectedMetadata: ""
        });
    }

    function test_confirmPassage_manuallyConfirmTwice() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        _nabu.assignPassageContent(workId, 1, passageOne);

        vm.roll(ONE_DAY);
        vm.prank(charlie);
        _nabu.assignPassageContent(workId, 1, passageOne);

        vm.roll(ONE_DAY + SEVEN_DAYS);
        vm.prank(dave);
        _nabu.assignPassageContent(workId, 1, passageOne);

        ReadablePassage memory passage = _nabu.getPassage(workId, 1);

        assertPassage({
            actual: passage,
            expectedAt: ONE_DAY + SEVEN_DAYS,
            expectedByZero: bob,
            expectedByOne: charlie,
            expectedByTwo: dave,
            expectedContent: passageOne,
            expectedMetadataBy: address(0),
            expectedMetadataAt: 0,
            expectedMetadata: ""
        });
    }

    function test_confirmPassage_reverts_whenCallerDoubleConfirms() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        _nabu.assignPassageContent(workId, 1, passageOne);

        vm.roll(ONE_DAY);
        vm.prank(charlie);
        _nabu.confirmPassageContent(workId, 1);

        vm.roll(ONE_DAY + SEVEN_DAYS);
        vm.prank(charlie);
        vm.expectRevert(abi.encodeWithSelector(CannotDoubleConfirmPassage.selector));
        _nabu.confirmPassageContent(workId, 1);
    }

    function test_confirmPassage_reverts_whenCallerManuallyDoubleConfirms() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        _nabu.assignPassageContent(workId, 1, passageOne);

        vm.roll(ONE_DAY);
        vm.prank(charlie);
        _nabu.assignPassageContent(workId, 1, passageOne);

        vm.roll(ONE_DAY + SEVEN_DAYS);
        vm.prank(charlie);
        vm.expectRevert(abi.encodeWithSelector(CannotDoubleConfirmPassage.selector));
        _nabu.assignPassageContent(workId, 1, passageOne);
    }

    function test_assignPassageContent_reverts_whenContentIsTooLong() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ContentTooLarge.selector));
        _nabu.assignPassageContent(workId, 1, passageTooLong);
    }

    function test_adminAssignPassageContent_reverts_whenContentIsTooLong() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ContentTooLarge.selector));
        _nabu.adminAssignPassageContent(workId, 1, passageTooLong);
    }

    function test_confirmPassage_reverts_whenPassageHasNoContent() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(NoPassageContent.selector));
        _nabu.confirmPassageContent(workId, 1);
    }

    function test_createWork_reverts_whenWorkHasNoPassages() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ZeroPassagesCount.selector));

        _nabu.createWork("Nemo", "Metadata?", "Nada", 0, "https://noth.ing/{id}.json", 1, alice);
    }

    function test_createWork_whenWorkHasEmptyTitle() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(EmptyTitle.selector));

        _nabu.createWork("Nemo", "Metadata?", "", 10_000, "https://noth.ing/{id}.json", 1, alice);
    }

    function test_createWork_mintsToCallerWithoutMintTo() public {
        vm.prank(charlie);

        uint256 workId =
            _nabu.createWork("Nemo", "Metadata?", "Nada", 10_000, "https://noth.ing/{id}.json", 69_420, address(0));

        assertEq(_ashurbanipal.balanceOf(address(charlie), workId), 69_420, "Balance mismatch");
    }

    function test_getPassage_reverts_whenIdIsInvalid() public {
        uint256 workId = createWork(alice);
        vm.expectRevert(abi.encodeWithSelector(InvalidPassageId.selector));
        _nabu.getPassage(workId, 1_000_001);
    }

    function test_assignPassageContent_reverts_whenPassageIsFinalized() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        _nabu.assignPassageContent(workId, 1, passageOne);

        vm.roll(ONE_DAY);
        vm.prank(charlie);
        _nabu.assignPassageContent(workId, 1, passageOne);

        vm.roll(ONE_DAY + SEVEN_DAYS);
        vm.prank(dave);
        _nabu.assignPassageContent(workId, 1, passageOne);

        vm.prank(mallory);
        vm.expectRevert(abi.encodeWithSelector(PassageAlreadyFinalized.selector));
        _nabu.assignPassageContent(workId, 1, passageOneMalicious);
    }

    function test_confirmPassage() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        _nabu.assignPassageContent(workId, 1, passageOne);

        vm.roll(ONE_DAY);
        vm.prank(charlie);
        _nabu.confirmPassageContent(workId, 1);

        ReadablePassage memory passage = _nabu.getPassage(workId, 1);

        assertPassage({
            actual: passage,
            expectedAt: ONE_DAY,
            expectedByZero: bob,
            expectedByOne: charlie,
            expectedByTwo: address(0),
            expectedContent: passageOne,
            expectedMetadataBy: address(0),
            expectedMetadataAt: 0,
            expectedMetadata: ""
        });
    }

    function test_confirmPassage_twice() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        _nabu.assignPassageContent(workId, 1, passageOne);

        vm.roll(ONE_DAY);
        vm.prank(charlie);
        _nabu.confirmPassageContent(workId, 1);

        vm.roll(ONE_DAY + SEVEN_DAYS);
        vm.prank(dave);
        _nabu.confirmPassageContent(workId, 1);

        ReadablePassage memory passage = _nabu.getPassage(workId, 1);

        assertPassage({
            actual: passage,
            expectedAt: ONE_DAY + SEVEN_DAYS,
            expectedByZero: bob,
            expectedByOne: charlie,
            expectedByTwo: dave,
            expectedContent: passageOne,
            expectedMetadataBy: address(0),
            expectedMetadataAt: 0,
            expectedMetadata: ""
        });
    }

    function test_confirmPassage_reverts_whenPassageIsFinalized() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        _nabu.assignPassageContent(workId, 1, passageOne);

        vm.roll(ONE_DAY);
        vm.prank(charlie);
        _nabu.confirmPassageContent(workId, 1);

        vm.roll(ONE_DAY + SEVEN_DAYS);
        vm.prank(dave);
        _nabu.confirmPassageContent(workId, 1);

        vm.prank(mallory); // not that this is really malicious
        vm.expectRevert(abi.encodeWithSelector(PassageAlreadyFinalized.selector));
        _nabu.confirmPassageContent(workId, 1);
    }

    function test_confirmPassage_reverts_whenCallerIsBlacklisted() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(alice);
        _nabu.updateBlacklist(workId, charlie, true);

        vm.prank(bob);
        _nabu.assignPassageContent(workId, 1, passageOne);

        vm.roll(ONE_DAY);
        vm.prank(charlie);
        vm.expectRevert(abi.encodeWithSelector(Blacklisted.selector));
        _nabu.confirmPassageContent(workId, 1);
    }

    function test_overwritePassage() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(mallory);
        _nabu.assignPassageContent(workId, 1, passageOneMalicious);

        ReadablePassage memory maliciousPassage = _nabu.getPassage(workId, 1);

        assertPassage({
            actual: maliciousPassage,
            expectedAt: 0,
            expectedByZero: mallory,
            expectedByOne: address(0),
            expectedByTwo: address(0),
            expectedContent: passageOneMalicious,
            expectedMetadataBy: address(0),
            expectedMetadataAt: 0,
            expectedMetadata: ""
        });

        vm.roll(ONE_DAY);
        vm.prank(alice);
        _nabu.assignPassageContent(workId, 1, passageOne);

        ReadablePassage memory passage = _nabu.getPassage(workId, 1);

        assertPassage({
            actual: passage,
            expectedAt: ONE_DAY,
            expectedByZero: alice,
            expectedByOne: address(0),
            expectedByTwo: address(0),
            expectedContent: passageOne,
            expectedMetadataBy: address(0),
            expectedMetadataAt: 0,
            expectedMetadata: ""
        });
    }

    function test_overwritePassage_twice() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(alice);
        _nabu.assignPassageContent(workId, 1, passageOne);

        ReadablePassage memory passage = _nabu.getPassage(workId, 1);

        assertPassage({
            actual: passage,
            expectedAt: 0,
            expectedByZero: alice,
            expectedByOne: address(0),
            expectedByTwo: address(0),
            expectedContent: passageOne,
            expectedMetadataBy: address(0),
            expectedMetadataAt: 0,
            expectedMetadata: ""
        });

        vm.roll(ONE_DAY);
        vm.prank(mallory);
        _nabu.assignPassageContent(workId, 1, passageOneMalicious);

        ReadablePassage memory maliciousPassage = _nabu.getPassage(workId, 1);

        assertPassage({
            actual: maliciousPassage,
            expectedAt: ONE_DAY,
            expectedByZero: mallory,
            expectedByOne: address(0),
            expectedByTwo: address(0),
            expectedContent: passageOneMalicious,
            expectedMetadataBy: address(0),
            expectedMetadataAt: 0,
            expectedMetadata: ""
        });

        vm.roll(ONE_DAY + SEVEN_DAYS);
        vm.prank(alice);
        _nabu.assignPassageContent(workId, 1, passageOne);

        ReadablePassage memory restoredPassage = _nabu.getPassage(workId, 1);

        assertPassage({
            actual: restoredPassage,
            expectedAt: ONE_DAY + SEVEN_DAYS,
            expectedByZero: alice,
            expectedByOne: address(0),
            expectedByTwo: address(0),
            expectedContent: passageOne,
            expectedMetadataBy: address(0),
            expectedMetadataAt: 0,
            expectedMetadata: ""
        });
    }

    function test_updateAshurbanipal() public {
        assertEq(_nabu.getAshurbanipalAddress(), address(_ashurbanipal), "Ashurbanipal address mismatch");

        _nabu.updateAshurbanipal(address(69));
        assertEq(_nabu.getAshurbanipalAddress(), address(69), "Ashurbanipal address mismatch");
    }

    function test_updateAshurbanipal_reverts_whenCallerIsNotOwner() public prank(mallory) {
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        _nabu.updateAshurbanipal(address(69));
    }

    function test_updateWorkAdmin() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        assertEq(_nabu.getWork(workId).admin, alice, "Work admin mismatch");

        vm.prank(alice);
        _nabu.updateWorkAdmin(workId, bob);
        assertEq(_nabu.getWork(workId).admin, bob, "Work admin mismatch");
    }

    function test_updateWorkAdmin_reverts_whenCallerIsNotAdmin() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(NotWorkAdmin.selector, alice));
        _nabu.updateWorkAdmin(workId, bob);
    }

    function test_updateWorkAuthor() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        assertEq(
            keccak256(bytes(_nabu.getWork(workId).author)),
            keccak256(bytes("Miguel de Cervantes")),
            "Work author mismatch"
        );

        vm.prank(alice);
        _nabu.updateWorkAuthor(workId, "Mickey C");
        assertEq(keccak256(bytes(_nabu.getWork(workId).author)), keccak256(bytes("Mickey C")), "Work author mismatch");
    }

    function test_updateWorkAuthor_reverts_whenCallerIsNotAdmin() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(NotWorkAdmin.selector, alice));
        _nabu.updateWorkAuthor(workId, "Mickey C");
    }

    function test_updateWorkAuthor_reverts_whenItsTooLate() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        vm.roll(THIRTY_DAYS + 1);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(TooLate.selector, THIRTY_DAYS));
        _nabu.updateWorkAuthor(workId, "Mickey C");
    }

    function test_updateBlacklist() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        assertFalse(_nabu.getIsBlacklisted(workId, mallory));

        vm.prank(alice);
        _nabu.updateBlacklist(workId, mallory, true);
        assertTrue(_nabu.getIsBlacklisted(workId, mallory));

        vm.prank(alice);
        _nabu.updateBlacklist(workId, mallory, false);
        assertFalse(_nabu.getIsBlacklisted(workId, mallory));
    }

    function test_updateBlacklist_reverts_whenCallerIsNotAdmin() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(NotWorkAdmin.selector, alice));
        _nabu.updateBlacklist(workId, charlie, true);
    }

    function test_updateBlacklist_succeedsCauseItsNeverTooLate() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        vm.roll(THIRTY_DAYS + 1);
        vm.prank(alice);
        _nabu.updateBlacklist(workId, bob, true);
    }

    function test_updateWorkMetadata() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        assertEq(
            keccak256(bytes(_nabu.getWork(workId).metadata)),
            keccak256(bytes("Original title: El ingenioso hidalgo don Quijote de la Mancha")),
            "Work metadata mismatch"
        );

        vm.prank(alice);
        _nabu.updateWorkMetadata(workId, "New metadata");
        assertEq(
            keccak256(bytes(_nabu.getWork(workId).metadata)), keccak256(bytes("New metadata")), "Work metadata mismatch"
        );
    }

    function test_updateWorkMetadata_reverts_whenCallerIsNotAdmin() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(NotWorkAdmin.selector, alice));
        _nabu.updateWorkMetadata(workId, "New metadata");
    }

    function test_updateWorkMetadata_reverts_whenItsTooLate() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        vm.roll(THIRTY_DAYS + 1);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(TooLate.selector, THIRTY_DAYS));
        _nabu.updateWorkMetadata(workId, "New metadata");
    }

    function test_updateWorkUri() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        assertEq(
            keccak256(bytes(_nabu.getWork(workId).uri)),
            keccak256(bytes("https://foo.bar/{id}.json")),
            "Work uri mismatch"
        );

        assertEq(
            keccak256(bytes(_ashurbanipal.uri(workId))),
            keccak256(bytes("https://foo.bar/{id}.json")),
            "Work uri mismatch"
        );

        vm.prank(alice);

        _nabu.updateWorkUri(workId, "https://lol.lmao/{id}.json");
        assertEq(
            keccak256(bytes(_nabu.getWork(workId).uri)),
            keccak256(bytes("https://lol.lmao/{id}.json")),
            "Work uri mismatch"
        );

        assertEq(
            keccak256(bytes(_ashurbanipal.uri(workId))),
            keccak256(bytes("https://lol.lmao/{id}.json")),
            "Work uri mismatch"
        );
    }

    function test_updateWorkUri_reverts_whenCallerIsNotAdmin() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(NotWorkAdmin.selector, alice));
        _nabu.updateWorkUri(workId, "https://lol.lmao/{id}.json");
    }

    function test_updateWorkUri_succeedsCauseItsNeverTooLate() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        vm.roll(THIRTY_DAYS + 1);
        vm.prank(alice);
        _nabu.updateWorkUri(workId, "https://lol.lmao/{id}.json");
    }

    function test_updateWorkTitle() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        assertEq(keccak256(bytes(_nabu.getWork(workId).title)), keccak256(bytes("Don Quijote")), "Work title mismatch");

        vm.prank(alice);
        _nabu.updateWorkTitle(workId, "Donny Q");
        assertEq(keccak256(bytes(_nabu.getWork(workId).title)), keccak256(bytes("Donny Q")), "Work title mismatch");
    }

    function test_updateWorkTitle_reverts_whenTitleIsEmpty() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(EmptyTitle.selector));
        _nabu.updateWorkTitle(workId, "");
    }

    function test_updateWorkTitle_reverts_whenCallerIsNotAdmin() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(NotWorkAdmin.selector, alice));
        _nabu.updateWorkTitle(workId, "Donny Q");
    }

    function test_updateWorkTitle_reverts_whenItsTooLate() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        vm.roll(THIRTY_DAYS + 1);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(TooLate.selector, THIRTY_DAYS));
        _nabu.updateWorkTitle(workId, "Donny Q");
    }

    function test_updateWorkTotalPassagesCount() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        assertEq(_nabu.getWork(workId).totalPassagesCount, 1_000_000, "Work total passages count mismatch");

        vm.prank(alice);
        _nabu.updateWorkTotalPassagesCount(workId, 69_000);
        assertEq(_nabu.getWork(workId).totalPassagesCount, 69_000, "Work total passages count mismatch");
    }

    function test_updateWorkTotalPassagesCount_reverts_whenCallerIsNotAdmin() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(NotWorkAdmin.selector, alice));
        _nabu.updateWorkTotalPassagesCount(workId, 69_000);
    }

    function test_updateWorkTotalPassagesCount_reverts_whenItsTooLate() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        vm.roll(THIRTY_DAYS + 1);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(TooLate.selector, THIRTY_DAYS));
        _nabu.updateWorkTotalPassagesCount(workId, 69_000);
    }

    function test_updateWorkTotalPassagesCount_reverts_whenPassageCountIsZero() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ZeroPassagesCount.selector));
        _nabu.updateWorkTotalPassagesCount(workId, 0);
    }

    function test_confirmPassage_reverts_whenItsTooSoon() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        _nabu.assignPassageContent(workId, 1, passageOne);

        vm.roll(ONE_DAY - 1);
        vm.prank(charlie);
        vm.expectRevert(abi.encodeWithSelector(TooSoonToConfirmContent.selector, ONE_DAY));
        _nabu.confirmPassageContent(workId, 1);
    }

    function test_confirmPassageManually_reverts_whenItsTooSoon() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        _nabu.assignPassageContent(workId, 1, passageOne);

        vm.roll(ONE_DAY - 1);
        vm.prank(charlie);
        vm.expectRevert(abi.encodeWithSelector(TooSoonToAssignContent.selector, ONE_DAY));
        _nabu.assignPassageContent(workId, 1, passageOne);
    }

    function test_confirmPassageSecondTime_reverts_whenItsTooSoon() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        _nabu.assignPassageContent(workId, 1, passageOne);

        vm.roll(ONE_DAY);
        vm.prank(charlie);
        _nabu.confirmPassageContent(workId, 1);

        vm.roll(ONE_DAY + SEVEN_DAYS - 1);
        vm.prank(dave);
        vm.expectRevert(abi.encodeWithSelector(TooSoonToConfirmContent.selector, ONE_DAY + SEVEN_DAYS));
        _nabu.confirmPassageContent(workId, 1);
    }

    function test_confirmPassageManuallySecondTime_reverts_whenItsTooSoon() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        _nabu.assignPassageContent(workId, 1, passageOne);

        vm.roll(ONE_DAY);
        vm.prank(charlie);
        _nabu.assignPassageContent(workId, 1, passageOne);

        vm.roll(ONE_DAY + SEVEN_DAYS - 1);
        vm.prank(dave);
        vm.expectRevert(abi.encodeWithSelector(TooSoonToAssignContent.selector, ONE_DAY + SEVEN_DAYS));
        _nabu.assignPassageContent(workId, 1, passageOne);
    }

    function test_adminAssignPassageContent_whenContentIsFinalized() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        _nabu.assignPassageContent(workId, 1, passageOneMalicious);

        vm.roll(ONE_DAY);
        vm.prank(charlie);
        _nabu.assignPassageContent(workId, 1, passageOneMalicious);

        vm.roll(ONE_DAY + SEVEN_DAYS);
        vm.prank(dave);
        _nabu.assignPassageContent(workId, 1, passageOneMalicious);

        ReadablePassage memory passageBefore = _nabu.getPassage(workId, 1);

        assertPassage({
            actual: passageBefore,
            expectedAt: ONE_DAY + SEVEN_DAYS,
            expectedByZero: bob,
            expectedByOne: charlie,
            expectedByTwo: dave,
            expectedContent: passageOneMalicious,
            expectedMetadataBy: address(0),
            expectedMetadataAt: 0,
            expectedMetadata: ""
        });

        vm.prank(alice);
        _nabu.adminAssignPassageContent(workId, 1, passageOne);

        ReadablePassage memory passage = _nabu.getPassage(workId, 1);

        assertPassage({
            actual: passage,
            expectedAt: ONE_DAY + SEVEN_DAYS,
            expectedByZero: alice,
            expectedByOne: address(0),
            expectedByTwo: address(0),
            expectedContent: passageOne,
            expectedMetadataBy: address(0),
            expectedMetadataAt: 0,
            expectedMetadata: ""
        });
    }

    function test_adminAssignPassageContent_reverts_whenPassageIdIsInvalid() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(InvalidPassageId.selector));
        _nabu.adminAssignPassageContent(workId, 1_000_001, passageOne);
    }

    function test_confirmPassageContent_reverts_whenPassageIdIsInvalid() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        vm.expectRevert(abi.encodeWithSelector(InvalidPassageId.selector));
        _nabu.confirmPassageContent(workId, 1_000_001);
    }

    function test_updateWorkAdmin_reverts_whenOldAdminAttemptsUpdate() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        assertEq(_nabu.getWork(workId).admin, alice, "Work admin before mismatch");

        vm.startPrank(alice, alice);
        _nabu.updateWorkAdmin(workId, bob);
        assertEq(_nabu.getWork(workId).admin, bob, "Work admin after mismatch");

        vm.expectRevert(abi.encodeWithSelector(NotWorkAdmin.selector, bob));
        _nabu.updateWorkTitle(workId, "Donny Q");
        vm.stopPrank();
    }

    function test_updateWorkAdmin_newAdminCanUpdateTitle() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        assertEq(_nabu.getWork(workId).admin, alice, "Work admin mismatch");

        vm.prank(alice);
        _nabu.updateWorkAdmin(workId, bob);
        assertEq(_nabu.getWork(workId).admin, bob, "Work admin mismatch");

        assertEq(keccak256(bytes(_nabu.getWork(workId).title)), keccak256(bytes("Don Quijote")), "Work title mismatch");

        vm.prank(bob);
        _nabu.updateWorkTitle(workId, "Donny Q");
        assertEq(keccak256(bytes(_nabu.getWork(workId).title)), keccak256(bytes("Donny Q")), "Work title mismatch");
    }

    function test_assignPassageMetadata() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        // Bob assigns content first
        vm.prank(bob);
        _nabu.assignPassageContent(workId, 1, passageOne);

        // Charlie assigns metadata immediately (no cooldown when no metadata yet and content exists)
        vm.prank(charlie);
        _nabu.assignPassageMetadata(workId, 1, passageOneMetadata);

        ReadablePassage memory passage = _nabu.getPassage(workId, 1);

        assertPassage({
            actual: passage,
            expectedAt: 0,
            expectedByZero: bob,
            expectedByOne: address(0),
            expectedByTwo: address(0),
            expectedContent: passageOne,
            expectedMetadataBy: charlie,
            expectedMetadataAt: 0,
            expectedMetadata: passageOneMetadata
        });
    }

    function test_assignPassageMetadata_reverts_whenContentIsTooLong() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(MetadataTooLarge.selector));
        _nabu.assignPassageMetadata(workId, 1, passageTooLong);
    }

    function test_assignPassageMetadata_reverts_whenOverwritingOwnMetadata() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        _nabu.assignPassageContent(workId, 1, passageOne);

        vm.prank(charlie);
        _nabu.assignPassageMetadata(workId, 1, passageOneMetadata);

        // Charlie tries to reassign their own metadata even after waiting
        vm.roll(SEVEN_DAYS);
        vm.prank(charlie);
        vm.expectRevert(abi.encodeWithSelector(CannotReassignOwnMetadata.selector));
        _nabu.assignPassageMetadata(workId, 1, passageTwoMetadata);
    }

    function test_assignPassageMetadata_reverts_whenItsTooSoon() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        _nabu.assignPassageContent(workId, 1, passageOne);

        // Charlie assigns metadata at block 0; metadataAt = 0
        vm.prank(charlie);
        _nabu.assignPassageMetadata(workId, 1, passageOneMetadata);

        // Dave tries before SEVEN_DAYS have elapsed; canAssignAfter = 0 + SEVEN_DAYS
        vm.roll(SEVEN_DAYS - 1);
        vm.prank(dave);
        vm.expectRevert(abi.encodeWithSelector(TooSoonToAssignMetadata.selector, SEVEN_DAYS));
        _nabu.assignPassageMetadata(workId, 1, passageTwoMetadata);
    }

    function test_assignPassageMetadata_reverts_whenPassageIdIsInvalid() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(InvalidPassageId.selector));
        _nabu.assignPassageMetadata(workId, 1_000_001, passageOneMetadata);
    }

    function test_assignPassageMetadata_reverts_whenCallerIsBlacklisted() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(alice);
        _nabu.updateBlacklist(workId, bob, true);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Blacklisted.selector));
        _nabu.assignPassageMetadata(workId, 1, passageOneMetadata);
    }

    function test_assignPassageMetadata_reverts_whenCallerHasNoPass() public {
        vm.prank(alice);
        uint256 workId = createWork(alice);

        // frank holds no passes for this work
        vm.prank(frank);
        vm.expectRevert(abi.encodeWithSelector(NoPass.selector));
        _nabu.assignPassageMetadata(workId, 1, passageOneMetadata);
    }

    function test_assignPassageMetadata_reverts_whenPassageIsFinalized() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        _nabu.assignPassageContent(workId, 1, passageOne);

        vm.roll(ONE_DAY);
        vm.prank(charlie);
        _nabu.confirmPassageContent(workId, 1);

        vm.roll(ONE_DAY + SEVEN_DAYS);
        vm.prank(dave);
        _nabu.confirmPassageContent(workId, 1);

        vm.prank(mallory);
        vm.expectRevert(abi.encodeWithSelector(PassageAlreadyFinalized.selector));
        _nabu.assignPassageMetadata(workId, 1, passageOneMetadata);
    }

    function test_assignPassageMetadata_reverts_whenUnchanged() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        _nabu.assignPassageContent(workId, 1, passageOne);

        vm.prank(charlie);
        _nabu.assignPassageMetadata(workId, 1, passageOneMetadata);

        // Dave tries to assign identical metadata after the cooldown
        vm.roll(SEVEN_DAYS);
        vm.prank(dave);
        vm.expectRevert(abi.encodeWithSelector(NoChangeInMetadata.selector));
        _nabu.assignPassageMetadata(workId, 1, passageOneMetadata);
    }

    function test_adminAssignPassageMetadata() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        // Finalize the passage
        vm.prank(bob);
        _nabu.assignPassageContent(workId, 1, passageOne);

        vm.roll(ONE_DAY);
        vm.prank(charlie);
        _nabu.confirmPassageContent(workId, 1);

        vm.roll(ONE_DAY + SEVEN_DAYS);
        vm.prank(dave);
        _nabu.confirmPassageContent(workId, 1);

        // Admin assigns metadata to the finalized passage
        vm.prank(alice);
        _nabu.adminAssignPassageMetadata(workId, 1, passageOneMetadata);

        // byTwo should be cleared: the passage is no longer finalized, allowing the community
        // to re-confirm (and implicitly endorse the admin-assigned metadata) or withhold
        ReadablePassage memory passage = _nabu.getPassage(workId, 1);

        assertPassage({
            actual: passage,
            expectedAt: ONE_DAY + SEVEN_DAYS,
            expectedByZero: bob,
            expectedByOne: charlie,
            expectedByTwo: address(0),
            expectedContent: passageOne,
            expectedMetadataBy: alice,
            expectedMetadataAt: ONE_DAY + SEVEN_DAYS,
            expectedMetadata: passageOneMetadata
        });

        // Give frank a pass so he can re-finalize
        vm.prank(alice);
        _ashurbanipal.safeTransferFrom(alice, frank, workId, 1, "");

        // A new independent confirmer (frank, who hasn't participated) can re-finalize the passage,
        // implicitly endorsing the existing content and admin-assigned metadata
        vm.roll(ONE_DAY + SEVEN_DAYS + SEVEN_DAYS);
        vm.prank(frank);
        _nabu.confirmPassageContent(workId, 1);

        passage = _nabu.getPassage(workId, 1);

        assertPassage({
            actual: passage,
            expectedAt: ONE_DAY + SEVEN_DAYS + SEVEN_DAYS,
            expectedByZero: bob,
            expectedByOne: charlie,
            expectedByTwo: frank,
            expectedContent: passageOne,
            expectedMetadataBy: alice,
            expectedMetadataAt: ONE_DAY + SEVEN_DAYS,
            expectedMetadata: passageOneMetadata
        });
    }

    function test_adminAssignPassageMetadata_reverts_whenMetadataIsTooLong() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MetadataTooLarge.selector));
        _nabu.adminAssignPassageMetadata(workId, 1, passageTooLong);
    }

    function test_adminAssignPassageMetadata_reverts_whenPassageIdIsInvalid() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(InvalidPassageId.selector));
        _nabu.adminAssignPassageMetadata(workId, 1_000_001, passageOneMetadata);
    }

    function test_getPassage_whenContentIsUnassigned() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        // Assign metadata to a passage that has no content yet
        vm.prank(bob);
        _nabu.assignPassageMetadata(workId, 1, passageOneMetadata);

        ReadablePassage memory passage = _nabu.getPassage(workId, 1);

        assertPassage({
            actual: passage,
            expectedAt: 0,
            expectedByZero: address(0),
            expectedByOne: address(0),
            expectedByTwo: address(0),
            expectedContent: "",
            expectedMetadataBy: bob,
            expectedMetadataAt: 0,
            expectedMetadata: passageOneMetadata
        });
    }

    function test_getPassage_whenMetadataIsUnassigned() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        _nabu.assignPassageContent(workId, 1, passageOne);

        ReadablePassage memory passage = _nabu.getPassage(workId, 1);

        assertPassage({
            actual: passage,
            expectedAt: 0,
            expectedByZero: bob,
            expectedByOne: address(0),
            expectedByTwo: address(0),
            expectedContent: passageOne,
            expectedMetadataBy: address(0),
            expectedMetadataAt: 0,
            expectedMetadata: ""
        });
    }

    function test_getPassage_whenContentAndMetadataAreUnassigned() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        ReadablePassage memory passage = _nabu.getPassage(workId, 1);

        assertPassage({
            actual: passage,
            expectedAt: 0,
            expectedByZero: address(0),
            expectedByOne: address(0),
            expectedByTwo: address(0),
            expectedContent: "",
            expectedMetadataBy: address(0),
            expectedMetadataAt: 0,
            expectedMetadata: ""
        });
    }

    // ── PassCooldown ──────────────────────────────────────────────────────────

    function test_assignPassageContent_reverts_whenPassCooldownIsActive() public {
        // Create work at block 1, then transfer a pass to bob at block 1
        vm.roll(1);
        vm.startPrank(alice);
        uint256 workId = createWork(alice);
        _ashurbanipal.safeTransferFrom(alice, bob, workId, 1_000, "");
        vm.stopPrank();

        // Bob received passes at block 1; cooldown expires at block 1 + ONE_DAY
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(PassCooldown.selector, 1 + ONE_DAY));
        _nabu.assignPassageContent(workId, 1, passageOne);
    }

    function test_assignPassageContent_succeeds_afterPassCooldownExpires() public {
        vm.roll(1);
        vm.startPrank(alice);
        uint256 workId = createWork(alice);
        _ashurbanipal.safeTransferFrom(alice, bob, workId, 1_000, "");
        vm.stopPrank();

        vm.roll(1 + ONE_DAY);
        vm.prank(bob);
        _nabu.assignPassageContent(workId, 1, passageOne);
    }

    function test_confirmPassageContent_reverts_whenPassCooldownIsActive() public {
        // Alice assigns content (she minted, so no cooldown)
        vm.roll(1);
        vm.prank(alice);
        uint256 workId = createWork(alice);

        vm.prank(alice);
        _nabu.assignPassageContent(workId, 1, passageOne);

        // Transfer a pass to bob after content is assigned
        vm.roll(2);
        vm.prank(alice);
        _ashurbanipal.safeTransferFrom(alice, bob, workId, 1_000, "");

        // Bob is in the confirmation window (ONE_DAY has passed since content) but still in cooldown
        vm.roll(1 + ONE_DAY);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(PassCooldown.selector, 2 + ONE_DAY));
        _nabu.confirmPassageContent(workId, 1);
    }

    function test_assignPassageMetadata_reverts_whenPassCooldownIsActive() public {
        // Alice creates work and assigns content (mint recipient — no cooldown)
        vm.roll(1);
        vm.startPrank(alice);
        uint256 workId = createWork(alice);
        _nabu.assignPassageContent(workId, 1, passageOne);
        // Transfer passes to charlie; charlie's cooldown starts at block 1
        _ashurbanipal.safeTransferFrom(alice, charlie, workId, 500, "");
        vm.stopPrank();

        // Charlie is still within the one-day holding period
        vm.roll(2);
        vm.prank(charlie);
        vm.expectRevert(abi.encodeWithSelector(PassCooldown.selector, 1 + ONE_DAY));
        _nabu.assignPassageMetadata(workId, 1, passageOneMetadata);
    }

    function test_passReceivedAt_resetsWhenBalanceReplenishedFromZero() public {
        vm.roll(1);
        vm.startPrank(alice);
        uint256 workId = createWork(alice);
        _ashurbanipal.safeTransferFrom(alice, bob, workId, 1_000, "");
        vm.stopPrank();

        assertEq(_ashurbanipal.passReceivedAt(workId, bob), 1, "passReceivedAt should be block 1 after first transfer");

        // Bob transfers all passes away — balance goes to zero
        vm.roll(2);
        vm.prank(bob);
        _ashurbanipal.safeTransferFrom(bob, charlie, workId, 1_000, "");

        // Alice transfers passes back to bob — balance replenished from zero
        vm.roll(3);
        vm.prank(alice);
        _ashurbanipal.safeTransferFrom(alice, bob, workId, 500, "");

        assertEq(_ashurbanipal.passReceivedAt(workId, bob), 3, "passReceivedAt should reset to block 3");
    }

    function test_passCooldown_doesNotApplyToMintRecipient() public {
        // Alice mints at block 1 — passReceivedAt stays at 0 (mint excluded from hook)
        vm.roll(1);
        vm.prank(alice);
        uint256 workId = createWork(alice);

        // Alice should be able to act immediately (mint recipients have no cooldown)
        vm.prank(alice);
        _nabu.assignPassageContent(workId, 1, passageOne);
    }
}
