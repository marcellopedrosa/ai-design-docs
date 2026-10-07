import { getRequestConfig } from 'next-intl/server';
import ptBRMessages from './messages/pt-BR.json';

export default getRequestConfig(() => ({
  locale: 'pt-BR',
  messages: ptBRMessages,
  timeZone: 'America/Recife',
}));
