package com.project.ecommerce.Fragments

import android.app.AlertDialog
import android.os.Bundle
import androidx.fragment.app.Fragment
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import com.afollestad.materialdialogs.MaterialDialog
import com.google.firebase.firestore.FirebaseFirestore
import com.project.ecommerce.Model.Dados
import com.project.ecommerce.R
import com.squareup.picasso.Picasso
import com.xwray.groupie.GroupAdapter
import com.xwray.groupie.Item
import com.xwray.groupie.ViewHolder
import kotlinx.android.synthetic.main.fragment_produtos.*
import kotlinx.android.synthetic.main.lista_produtos.view.*
import kotlinx.android.synthetic.main.money.*
import java.text.FieldPosition


class Produtos : Fragment() {
    private lateinit var adapter: GroupAdapter<ViewHolder>
    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        // Inflate the layout for this fragment
        return inflater.inflate(R.layout.fragment_produtos, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        adapter = GroupAdapter()
        recycler_produtos.adapter = adapter
        adapter.setOnItemClickListener{ item, view ->

            val Dialog = LayoutInflater.from(context).inflate(R.layout.money, null)
            val builder = AlertDialog.Builder(context)
                .setView(Dialog)
                .setTitle("Formas de Pagamanto")
            val mAlertDialog = builder.show()
            mAlertDialog.bt_Pay.setOnClickListener {
                mAlertDialog.dismiss()
                val pay = mAlertDialog.form_Pay.text.toString()

                if(pay == "249,90"){
                    Toast.makeText(context, "Pagamento Realizado!", Toast.LENGTH_SHORT).show()
                    /*MaterialDialog.Builder(this!!.context!!)
                        .title("Pagamento concluído")
                        .content("Obrigado! Volte sempre.")*/
                }else{
                    Toast.makeText(context, "Pagamento Recusado", Toast.LENGTH_SHORT).show()
                }
            }
        }
        BuscarProdutos()
    }

    private inner class ProdutosItem(internal val adProdutos: Dados) : Item<ViewHolder>() {
        override fun getLayout(): Int {
            return R.layout.lista_produtos

        }

        override fun bind(viewHolder: ViewHolder, position: Int) {
            viewHolder.itemView.nomeProduto.text = adProdutos.nome
            viewHolder.itemView.precoProduto.text = adProdutos.preco
            Picasso.get().load(adProdutos.uid).into(viewHolder.itemView.fotoProduto)

        }
    }

    private fun BuscarProdutos() {
        FirebaseFirestore.getInstance().collection("Produtos")
            .addSnapshotListener { snapshot, exception ->
                exception?.let {
                    return@addSnapshotListener
                }
                snapshot?.let {
                    for (doc in snapshot) {
                        val produtos = doc.toObject(Dados::class.java)
                        adapter.add(ProdutosItem(produtos))
                    }
                }
            }
    }

}