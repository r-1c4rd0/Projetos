import 'package:flutter/material.dart';
import 'package:sortudo/home/widget/app_bar_widget.dart';

import '../model/user_model.dart';

class RegulationPage extends StatelessWidget {
  const RegulationPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget textSection = Container(
      padding: const EdgeInsets.all(32),
      child: const Expanded(
        child: Text(
          '1. CLÁUSULA PRIMEIRA - CONSIDERAÇÕES INICIAIS \n'
          '1.1. CONSIDERANDO que a Trevo Premiações, no exercício de sua atividade, possui reconhecida tradição no setor de premiações e sorteios, atraindo parcerias específicas da área a fim de viabilizar êxito e atingir objetivos da empresa;\n'
          '1.2. CONSIDERANDO que a plataforma de sorteios Trevo Premiações é baseada na efetiva venda de cotas referente aos bens sorteados;\n'
          '1.3. CONSIDERANDO que é obrigatória a maioridade (a partir de 18 anos) do Usuário para compra de cotas e participação no sorteio;\n'
          '1.4. CONSIDERANDO, por fim, que o presente instrumento regula e vincula, juridicamente, a relação entre Usuário e Trevo Premiações;\n'
          'O Usuário, ao finalizar seu cadastro, clicando na opção "Li e concordo com todas as condições do Termo de Aceite", passa a se obrigar as condições definidas neste acordo, bem como àquelas que possam vir a integrar o presente.\n\n'
          '\n2. CLÁUSULA SEGUNDA - DO OBJETO\n'
          '2.1. Constitui objeto do presente Termo de Aceite a venda de cotas, referente aos sorteios oferecidos pela plataforma da Trevo Premiações, bem como o efetivo sorteio do bem, realizado pela Loteria Federal.\n'
          '2.2. Concordam que é ilimitado o número de cotas adquiridas por Usuário, sendo que o valor anunciado corresponde a uma cota.\n'
          '2.3. As cotas poderão ser reservadas pelo prazo de 12 horas, não havendo o pagamento dentro do prazo os números serão liberados para demais interessados/usuários.\n'
          '\n3. CLÁUSULA TERCEIRA - DO PAGAMENTO\n'
          '3.1 O pagamento, referente à aquisição das cotas, deverá ser realizado em uma das contas exibidas, com devido envio do comprovante à Trevo Premiações, via whatsapp.\n'
          '3.2. Não será aceito pagamento via depósito, somente TED, boleto bancário, cartão de crédito ou pix.\n'
          '3.3. Em caso de pagamento via boleto, deverá ser observado e cumprido o prazo de vencimento, ficando o usuário sujeito a perda da cota em caso de não pagamento. O mesmo ocorrerá caso não haja aprovação do pagamento pelo cartão de crédito, ficando o Usuário responsável pela conferência da efetivação da compra e pagamento.\n'
          '\n4. CLÁUSULA QUARTA - DA CONCESSÃO PARA USO DA PLATAFORMA PELO USUÁRIO\n'
          '4.1. O acesso do Usuário a toda plataforma da TrevoPremiações será limitado, não exclusivo, pessoal, privado e intransferível, observados os limites do Usuário e sua maioridade.\n'
          '4.2. O Usuário se obriga a fornecer informações precisas e verdadeiras sobre seu endereço físico e identidade, incluindo nacionalidade;\n'
          '4.3. Ficará resguardado à Trevo Premiações o direito de solicitar, a qualquer tempo, comprovação de identificação do Usuário, ficando sujeito, o mesmo, ao cancelamento, temporário ou permanente, de sua conta em caso de possuir idade inferior a 18 anos.\n'
          '4.4. Poderá ser suspenso, sem aviso prévio, o cadastro de conta suspeita, até que o Usuário comprove sua idade ou demais informações necessárias para sanar possíveis dúvidas ou em caso de comportamento fraudulento, ficando o Usuário obrigado à apresentação da documentação solicitada e esclarecimentos, sob pena de cancelamento da conta.\n'
          '4.5. O Usuário deverá preservar as configurações mínimas de conexão de internet, bem como preservar seu login e senha, ficando obrigado a contatar a Trevo Premiações em havendo qualquer problema de uso à plataforma ou acesso de terceiros.\n'
          '4.6. O Usuário poderá possuir apenas uma conta nesta plataforma, ficando sujeito ao cancelamento das possíveis contas múltiplas, sem prévio aviso.\n'
          '\n5. DOS DIREITOS DE PROPRIEDADE INDUSTRIAL E INTELECTUAL '
          '5.1. Todos os direitos e propriedade intelectual, no tocante a esta plataforma e serviços oferecidos, são de propriedade total e definitiva da Trevo Promoções.\n'
          '5.2. Através deste contrato, portanto, fica estabelecido, apenas, a licença de uso da plataforma pelo Usuário cliente, comprador de cotas e participante de sorteios.\n'
          '5.3. É proibido ao Usuário traduzir, alterar, descomprimir, modificar, excluir, descompilar, copiar imagens, código ou quaisquer partes da plataforma, da forma que for.\n'
          '5.4. O Usuário se responsabiliza pelos seus dados fornecidos e imagens, bem como permite o uso das informações oferecidas, de modo irrevogável, irretratável e amplo, para qualquer propósito relativo aos objetivos da empresa Trevo Premiações.\n'
          '5.5. O Usuário declara ter lido todo o Termo de Aceite, concordando, integralmente, com as condições definidas.\n'
          '\n6. CLÁUSULA SEXTA - DO SORTEIO\n'
          '6.1.  Em regra, a realização do sorteio ocorrerá na data inicialmente divulgada na plataforma.\n'
          '6.2. Poderá ser aplicada exceção à regra contida no item anterior, em não havendo a efetiva venda e pagamento de todas as cotas, quando poderá ser adiado o sorteio, sendo divulgada nova data.\n'
          '6.3. A remarcação poderá ocorrer quantas vezes for necessário.\n'
          '6.4. O sorteio ocorrerá de modo on-line, por meio das redes sociais da Trevo Premiações, ficando facultado ao Usuário assistir ou não ao sorteio.\n'
          '6.5. Ficará a Trevo Premiações obrigada a entrar em contato com o Usuário Vencedor do sorteio, para confirmar o número sorteado, bem como sobre ser o vencedor contemplado.\n'
          '\n7. CLÁUSULA SÉTIMA - DAS OBRIGAÇÕES DO USUÁRIO\n'
          '7.1. O Usuário fica obrigado à:\n'
          '7.1.1. Possuir apenas uma conta ativa;\n'
          '7.1.2.Fornecer corretamente seus dados de identificação, comprovação de residência e telefone de contato;\n'
          '7.1.3. Possuir mais 18 anos ou mais.\n'
          '7.2. O Usuário concorda em indenizar, na totalidade, a Trevo Premiações, em relação à possíveis danos, perdas, custos e despesas, em caso de:\n'
          '7.2.1. Quebra do Termo, em sua totalidade ou em parte;\n'
          '7.2.2. Violação de preceitos legais ou direitos de terceiros;\n'
          '7.2.3. Utilização do serviço com dados falsos ou em caso de fornecimento de dados a terceiros, com ou sem consentimento.\n'
          '7.3. O Usuário é único responsável por quaisquer impostos que possam vir a incidir sobre os prêmios recebidos, ou demais encargos que venham a ser aplicáveis em decorrência da utilização dos serviços da TrevoPremiações.\n'
          '\n8. CLÁUSULA OITAVA - DAS OBRIGAÇÕES DA TREVO PREMIAÇÕES\n'
          '8.1. A Trevo Premiações, em nenhuma hipótese, se responsabilizará por quaisquer tipos de danos ou perdas pecuniárias decorrentes da utilização dos serviços desta pelo Usuário, ficando esta isenta à qualquer tipo de indenização, inclusive por perdas e danos.\n'
          '8.2. A Trevo Premiações poderá, a seu critério, rescindir este contrato, caso o Usuário não cumpra com as obrigações da cláusula sétima, ou qualquer outra deste Termo de Aceite, neste caso, a Trevo Premiações se obriga a devolução dos valores pagos pelo Usuário, se for o caso.\n'
          '8.3. A Trevo Premiações não fornecerá instruções aos Usuários sobre situações fiscais e/ou legais que incidem sobre o prêmio recebido.\n'
          '8.4. A Trevo Premiações se obriga, no caso de premio de veículo ou moto zero km/novo, ao faturamento do bem no prazo de 30 (trinta) dias úteis.\n'
          '8.5. A Trevo Premiações se obriga à entrega do Documento Único de Transferência (DUT), juntamente com o bem usado ao Vencedor, se este for o caso.\n'
          '\n9. CLÁUSULA NONA - DA ENTREGA DO PRÊMIO\n'
          '9.1. O bem sorteado, em regra, será veículos automotores, contudo, poderá ser oferecido, única e exclusivamente,pela Trevo Premiações, a troca do bem sorteado por determinada quantia em dinheiro.\n'
          '9.2. No caso de o Usuário vencedor optar pelo recebimento da quantia em dinheiro, oferecida Trevo Premiações, a mesma se comprometerá à transferência da quantia em até 30 (trinta) dias, após confirmação dos dados bancários do Usuário vencedor.\n'
          '9.3. A entrega do prêmio sorteado, seja o próprio bem ouvalor correspondente a ele, somente ocorrerá mediante confirmação dos dados pelo Usuário vencedor, fornecidos no ato do cadastramento nesta plataforma.\n'
          '9.4. Em hipótese alguma o prêmio sorteado será entregue a terceiros, mesmo que haja parentesco entre o terceiro e o Usuário.\n'
          "9.5. Em caso de sorteio de veículos/motos zero km/novos, a entrega estará condicionada, exclusivamente, ao prazo apresentado pela concessionária, ou seja, a Trevo Premiações se responsabiliza, apenas, pelo faturamento do bem e não pela data de entrega.\n"
          ""
          '9.6. Em se tratando de bem usado, o prazo de entrega será em até 120 (cento e vinte) dias úteis.\n'
          '9.7. A Trevo Premiações gravará um vídeo, juntamente com o ganhador, para fins de divulgação da concretização do sorteio, estando o usuário/ganhador em total concordância com a gravação, bem como a divulgação deste vídeo.\n'
          '\n10. CLÁUSULA DÉCIMA – DA MODIFICAÇÃO DO PRÊMIO\n'
          '10.1. Será possível e legítima a troca/modificação do prêmio, estando o Usuário em perfeita concordância, em ocorrência de caso fortuito ou força maior.\n'
          '10.2. Será considerado caso fortuito ou de força maior, sem taxatividade:\n'
          '10.2.1. Possível gravame que venha a integrar o documento do bem ou que não seja de conhecimento da Trevo Premiações;\n'
          '10.2.2. O roubo ou furto do bem premiado;\n'
          '10.2.3. Perda total ou parcial do bem.\n'
          '10.4. No caso de modificação do prêmio, nos termos acima, a troca será por outro bem, semelhante àquele anunciado primeiro.\n'
          '\n11. CLÁUSULA DÉCIMA PRIMEIRA -CONSIDERAÇÕES GERAIS\n'
          '11.1. Em caso de alteração dos termos deste acordo, a Trevo Premiações irá informar por meio de e-mail, enviado ao endereço eletrônico informado pelo Usuário, momento em que o mesmo deverá aceitar as novas condições para continuar possuindo acesso à plataforma.\n'
          '11.2. O presente Termo de Aceite reflete a vontade das partes contratantes, obrigando estes ao cumprimento integral deste instrumento.\n'
          '11.3. Fica vedado ao Usuário à cessão, gratuita ou onerosa, total ou parcial, dos direitos e obrigações decorrentes deste Termo de Aceite, sendo permito apenas a Trevo Premiações o direito de ceder este Acordo, na sua totalidade ou parcialmente.\n'
          'O presente Termo de Aceite entra em vigor a partir de junho de 2021, com efeitos retroativos.\n',
          softWrap: true,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBarWidget(
          user: UserModel(
        name: 'Ricardo',
        photoUrl: 'https://avatars.githubusercontent.com/u/28695175?s=40&v=4',
      )),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const Center(
              child: Text('Regulamento\n', style: TextStyle(fontSize: 20)),
            ),
            const Text(
                'Obrigado por escolher a Trevo Premiações!\n'
                'É um prazer ter você como cliente.\n',
                textAlign: TextAlign.center),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'A Sortudo Premiações, empresa filantrópica premiável, regulamentada pela Lei Federal nº 13.019/14, estabelece os seguintes termos e condições:\n',
                textAlign: TextAlign.center,
              ),
            ),
            textSection,
          ],
        ),
      ),
    );
  }
}
