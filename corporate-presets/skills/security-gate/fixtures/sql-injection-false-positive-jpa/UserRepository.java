// Exemplo de consulta parametrizada segura via Spring Data JPA - NÃO é SQL Injection
@Repository
public interface UserRepository extends JpaRepository<User, Long> {
    List<User> findByNameContainingIgnoreCase(String name);

    @Query("SELECT u FROM User u WHERE u.email = :email")
    Optional<User> findByEmailParam(@Param("email") String email);
}
