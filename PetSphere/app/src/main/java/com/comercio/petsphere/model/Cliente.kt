package com.comercio.petsphere.model

data class Cliente(
    var nome: String,
    var email: String,
    var telefone: String,
    var endereco: String,
    var animais: MutableList<Animal> = mutableListOf(),
    override var login: String,
    override var senha: String
) : Usuario(login, senha) {

    // Implementação dos métodos abstratos de Usuario
    override fun adicionarUsuario() {
        // Implementação específica para adicionar um cliente
        println("Usuário $nome adicionado com sucesso!")
    }

    override fun atualizarUsuario() {
        // Implementação específica para atualizar um cliente
        println("Usuário $nome atualizado com sucesso!")
    }

    override fun deleteUsuario() {
        // Implementação específica para deletar um cliente
        println("Usuário $nome deletado com sucesso!")
    }

    // Método para adicionar um animal ao cliente
    fun adicionarAnimal(animal: Animal) {
        animais.add(animal)
    }

    // Método para remover um animal do cliente
    fun removerAnimal(animal: Animal) {
        animais.remove(animal)
    }

    // Método para exibir informações do cliente e seus animais
    fun exibirInformacoes(): String {
        val infoCliente = "Nome: $nome\nEmail: $email\nTelefone: $telefone\nEndereço: $endereco\nLogin: $login"
        val infoAnimais = if (animais.isNotEmpty()) {
            animais.joinToString(separator = "\n\n") { it.exibirInformacoes() }
        } else {
            "Nenhum animal registrado."
        }
        return "$infoCliente\n\nAnimais:\n$infoAnimais"
    }
}
