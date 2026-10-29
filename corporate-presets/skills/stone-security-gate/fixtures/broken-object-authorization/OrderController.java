// Endpoint autenticado mas sem validação de tenant/ownership (BOLA / IDOR)
@RestController
@RequestMapping("/api/orders")
public class OrderController {
    @Autowired
    private OrderRepository orderRepository;

    @GetMapping("/{orderId}")
    public ResponseEntity<Order> getOrder(@PathVariable Long orderId) {
        // VULNERABILIDADE: Busca ordem diretamente por ID sem verificar se pertence ao usuário autenticado
        return orderRepository.findById(orderId)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }
}
