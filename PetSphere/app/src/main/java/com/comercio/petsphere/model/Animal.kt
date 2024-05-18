package com.comercio.petsphere.model

data class Animal(
    var nome: String,
    var idade: Int,
    var especie: String,
    var raca: String,
    var peso: Double
) {
    // Método para exibir informações do animal
    fun exibirInformacoes(): String {
        return "Nome: $nome\nIdade: $idade anos\nEspécie: $especie\nRaça: $raca\nPeso: $peso kg"
    }

    // Método para atualizar o peso do animal
    fun atualizarPeso(novoPeso: Double) {
        peso = novoPeso
    }
}